//
//  FUGLView.m
//  FULiveDemo
//
//  Created by liuyang on 16/10/20.
//  Copyright © 2016年 liuyang. All rights reserved.
//

#import "FUGLView.h"
#import <GLKit/GLKit.h>
// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXCOORD
};

@interface FUGLView ()
{
    // The pixel dimensions of the CAEAGLLayer.
    GLint _backingWidth;
    GLint _backingHeight;
    
    int frameWidth;
    int frameHeight;
    
    EAGLContext *_context;
    CVOpenGLESTextureRef _texture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    GLuint _frameBufferHandle;
    GLuint _colorBufferHandle;
    
    GLfloat         _vertices[8];
    GLint displayInputTextureUniform;
    
    NSUInteger numberOfFramesCaptured;
    CGFloat totalFrameTimeDuringCapture;
}

@property GLuint program;

- (void)setupBuffers;
- (void)cleanUpTextures;
- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

@end

@implementation FUGLView

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking :[NSNumber numberWithBool:NO],
                                          kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8};
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_context || ![EAGLContext setCurrentContext:_context] || ![self loadShaders]) {
            return nil;
        }
    }
    return self;
}

# pragma mark - OpenGL setup

- (void)setupGL
{
    [EAGLContext setCurrentContext:_context];
    [self setupBuffers];
    [self loadShaders];
    
    glUseProgram(self.program);
    
    // Create CVOpenGLESTextureCacheRef for optimal CVPixelBufferRef to GLES texture conversion.
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
}

#pragma mark - Utilities

- (void)setupBuffers
{
    glDisable(GL_DEPTH_TEST);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    glGenRenderbuffers(1, &_colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    [self updateVertices];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorBufferHandle);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)cleanUpTextures
{
    if (_texture) {
        CFRelease(_texture);
        _texture = NULL;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)dealloc
{
    [self cleanUpTextures];
    
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
}

#pragma mark - OpenGLES drawing

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    
    glFinish();
    if (pixelBuffer == NULL) return;
    CVReturn err;
    
    int tmpWidth = frameWidth;
    int tmpHeight = frameHeight;
    
    frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    if (frameHeight != tmpHeight || frameWidth != tmpWidth) {
        return;
    }
    
    if (!_videoTextureCache) {
        NSLog(@"No video texture cache");
        return;
    }
    
    //NSLog(@"context%@",_context);
    if ([EAGLContext currentContext] != _context) {
//        NSLog(@"setDrawContextinThread--%@",[NSThread currentThread]);
        [EAGLContext setCurrentContext:_context];
    }else
    {
//        NSLog(@"notSetDrawContextinThread--%@",[NSThread currentThread]);
    }
    [self cleanUpTextures];
    
    //RGB
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _videoTextureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, frameWidth, frameHeight, GL_BGRA, GL_UNSIGNED_BYTE, 0, &_texture);
    
    if (!_texture || err) {
        NSLog(@"Camera CVOpenGLESTextureCacheCreateTextureFromImage failed (error: %d)", err);
        NSAssert(NO, @"Camera failure");
        return;
    }
    
    glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(_texture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    GLuint textureHandle = CVOpenGLESTextureGetName(_texture);

    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    // Set the view port to the entire view.
    glViewport(0, 0, _backingWidth, _backingHeight);

    glUseProgram(_program);
    
    glClearColor(0.1f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, textureHandle);
    glUniform1i(displayInputTextureUniform, 4);
    
    [self updateVertices];
    
    // 更新顶点数据
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    
    GLfloat quadTextureData[] =  { // 正常坐标
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f,  0.0f,
        1.0f,  0.0f,
    };
    
    if (_isFrontCamera) {
        quadTextureData[0] = 1.0f;
        quadTextureData[2] = 0.0f;
        quadTextureData[4] = 1.0f;
        quadTextureData[6] = 0.0f;
    }
    
    glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(ATTRIB_TEXCOORD);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _colorBufferHandle);
    
    if ([EAGLContext currentContext] == _context) {
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
}

- (CGFloat)averageFrameDurationDuringCapture;
{
    return (totalFrameTimeDuringCapture / (CGFloat)(numberOfFramesCaptured - 5)) * 1000.0;
}

- (void)updateVertices
{
    //    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = frameWidth;
    const float height  = frameHeight;
    const float dH      = (float)_backingHeight / height;
    const float dW      = (float)_backingWidth	  / width;
    const float dd      = NO ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_backingHeight);
    const float w       = (width  * dd / (float)_backingWidth );
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSURL *vertShaderURL, *fragShaderURL;
    
    
    self.program = glCreateProgram();
    
    // Create and compile the vertex shader.
    vertShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER URL:vertShaderURL]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderURL = [[NSBundle mainBundle] URLForResource:@"Shader" withExtension:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER URL:fragShaderURL]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(self.program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(self.program, fragShader);
    
    // Bind attribute locations. This needs to be done prior to linking.
    glBindAttribLocation(self.program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(self.program, ATTRIB_TEXCOORD, "inputTextureCoordinate");
    
    // Link the program.
    if (![self linkProgram:self.program]) {
        NSLog(@"Failed to link program: %d", self.program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (self.program) {
            glDeleteProgram(self.program);
            self.program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    displayInputTextureUniform = glGetUniformLocation(self.program, "inputImageTexture");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(self.program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(self.program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type URL:(NSURL *)URL
{
    NSError *error;
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (sourceString == nil) {
        NSLog(@"Failed to load vertex shader: %@", [error localizedDescription]);
        return NO;
    }
    
    GLint status;
    const GLchar *source;
    source = (GLchar *)[sourceString UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
