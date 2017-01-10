//
//  Shader.fsh
//  FULiveDemo
//
//  Created by liuyang on 16/10/20.
//  Copyright © 2016年 liuyang. All rights reserved.
//
uniform sampler2D inputImageTexture;

varying highp vec2 textureCoordinate;

void main()
{
    gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
}
