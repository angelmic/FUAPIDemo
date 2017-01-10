//
//  Shader.vsh
//  FULiveDemo
//
//  Created by liuyang on 16/10/20.
//  Copyright © 2016年 liuyang. All rights reserved.
//

attribute vec4 position;
attribute vec2 inputTextureCoordinate;

varying vec2 textureCoordinate;

void main()
{
    gl_Position = position;
    textureCoordinate = inputTextureCoordinate;
}
