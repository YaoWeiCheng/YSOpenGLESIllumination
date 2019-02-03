//
//  YSViewController.m
//  01-光照
//
//  Created by cyw on 2018/1/20.
//  Copyright © 2018年 cyw. All rights reserved.
//

#import "YSViewController.h"
#import "AGLKVertexAttribArrayBuffer.h"
#import "sceneUtil.h"

@interface YSViewController ()


@property(nonatomic,strong)EAGLContext *mContext;
//基本光照纹理
@property(nonatomic,strong)GLKBaseEffect *baseEffect;
//额外光照纹理
@property(nonatomic,strong)GLKBaseEffect *extraEffect;
//顶点缓存区
@property(nonatomic,strong)AGLKVertexAttribArrayBuffer *vertexBuffer;
//法线位置缓存区
@property(nonatomic,strong)AGLKVertexAttribArrayBuffer *extraBuffer;

//是否使用面法线
@property(nonatomic,assign)BOOL shouldUseFaceNormals;

//是否绘制法线
@property(nonatomic,assign)BOOL shouldDrawNormals;

//中心点的高
@property(nonatomic,assign) GLfloat centexVertexHeight;

@end

@implementation YSViewController
{
    //三角形-8面
    SceneTriangle triangles[NUM_FACES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
  
    //1.
    [self setUp];
    
    
}
#pragma mark -- OpenGL ES
-(void)setUp
{
    //1.新建OpenGL ES 上下文
    self.mContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.mContext;
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    //将mContext 设置为当前context
    [EAGLContext setCurrentContext:self.mContext];
    
    //2.设置灯光效果
    self.baseEffect = [[GLKBaseEffect alloc] init];
    self.baseEffect.light0.enabled = GL_TRUE;
    
    //光的漫射部分
    self.baseEffect.light0.diffuseColor = GLKVector4Make(0.7f, 0.7f, 0.7f, 1.0f);
    
    //世界坐标中的光的位置
    self.baseEffect.light0.position = GLKVector4Make(1.0f, 1.0f, 0.5f, 0.0f);
    
    //设置法线配置
    self.extraEffect = [[GLKBaseEffect alloc] init];
    self.extraEffect.useConstantColor = GL_TRUE;
    
    //调整模型矩阵，更好地观察
    //可以尝试不执行这段代码，改为false
    if (true) {
        
        //围绕x轴旋转-60度
        //返回一个4*4矩阵进行绕行任意矢量旋转
        GLKMatrix4 modelViewMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(-60.0f), 1.0f, 0.0f, 0.0f);
        //围绕Z轴，旋转-30度
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, GLKMathDegreesToRadians(-30.0f), 0.0f, 0.0f, 1.0f);
        
        //围绕Z方向，移动0.25f
        modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0f, 0.0f, 0.25f);
        
        //设置baseEffect，extraEffect 模型矩阵
        self.baseEffect.transform.modelviewMatrix = modelViewMatrix;
        //法线一样需要修改，因为是基于baseeffect变化的
        self.extraEffect.transform.modelviewMatrix = modelViewMatrix;
    }
    
    //设置清屏颜色
    [self setClearColor:GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)];
    
    //确定图形的8个面
    triangles[0] = SceneTriangleMake(vertexA, vertexB, vertexD);
    triangles[1] = SceneTriangleMake(vertexB, vertexC, vertexF);
    triangles[2] = SceneTriangleMake(vertexD, vertexB, vertexE);
    triangles[3] = SceneTriangleMake(vertexE, vertexB, vertexF);
    triangles[4] = SceneTriangleMake(vertexD, vertexE, vertexG);
    triangles[5] = SceneTriangleMake(vertexE, vertexF, vertexH);
    triangles[6] = SceneTriangleMake(vertexG, vertexD, vertexH);
    triangles[7] = SceneTriangleMake(vertexH, vertexF, vertexI);
    
    //初始化缓存区
    //顶点缓存区
    /*
     参数1：数据大小 3个GLFloat类型，x,y,z
     参数2：有多少个数据，count
     参数3：数据大小
     参数4：用途 GL_STATIC_DRAW，
     */
    self.vertexBuffer = [[AGLKVertexAttribArrayBuffer alloc] initWithAttribStride:sizeof(SceneVertex) numberOfVertices:sizeof(triangles)/sizeof(SceneVertex) bytes:triangles usage:GL_DYNAMIC_DRAW];
    //因为暂时不知道法线的个数和数据大小，所以参数二填写0，参数三暂时填写NULL
    self.extraBuffer = [[AGLKVertexAttribArrayBuffer alloc] initWithAttribStride:sizeof(SceneVertex) numberOfVertices:0 bytes:NULL usage:GL_DYNAMIC_DRAW];
    //中心点的高
    self.centexVertexHeight = 0.0f;
    //是否使用面法线
    self.shouldUseFaceNormals = YES;
}

- (void)setClearColor:(GLKVector4)clearColorRGBA
{
    glClearColor(clearColorRGBA.r,
                 clearColorRGBA.g,
                 clearColorRGBA.b,
                 clearColorRGBA.a);
}

#pragma mark -- GLKView DrawRect
-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    //设置清屏颜色
    glClearColor(0.3f, 0.3f, 0.3f, 0.3f);
    glClear(GL_COLOR_BUFFER_BIT);
    //准备绘制
    [self.baseEffect prepareToDraw];
    
    //准备绘制顶点数据
    
    /*
     其实就是把数据传递过去，然后指定读取方式
     参数1：数据是做什么用的
     参数2：数据读取个数
     参数3：数据读取索引
     参数4：是否调用glEnableVertexAttribArray
     
     着色器能否读取到数据，由是否启用了对应的属性决定，这就是glEnableVertexAttribArray的功能，允许顶点着色器读取GPU（服务器端）数据。
     
     
     默认情况下，出于性能考虑，所有顶点着色器的属性（Attribute）变量都是关闭的，意味着数据在着色器端是不可见的，哪怕数据已经上传到GPU，由glEnableVertexAttribArray启用指定属性，才可在顶点着色器中访问逐顶点的属性数据。glVertexAttribPointer或VBO只是建立CPU和GPU之间的逻辑连接，从而实现了CPU数据上传至GPU。但是，数据在GPU端是否可见，即，着色器能否读取到数据，由是否启用了对应的属性决定，这就是glEnableVertexAttribArray的功能，允许顶点着色器读取GPU（服务器端）数据。
     
     那么，glEnableVertexAttribArray应该在glVertexAttribPointer之前还是之后调用？答案是都可以，只要在绘图调用（glDraw*系列函数）前调用即可。
     */
    
    [self.vertexBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition numberOfCoordinates:3 attribOffset:offsetof(SceneVertex, position) shouldEnable:YES];
    
    //准备绘制光照数据
    [self.vertexBuffer prepareToDrawWithAttrib:GLKVertexAttribNormal numberOfCoordinates:3 attribOffset:offsetof(SceneVertex, normal) shouldEnable:YES];
    
    [self.vertexBuffer drawArrayWithMode:GL_TRIANGLES startVertexIndex:0 numberOfVertices:sizeof(triangles)/sizeof(SceneVertex)];
    
    //是否需要绘制光照法线
    if (self.shouldDrawNormals) {
        [self drawNormals];
    }
}


//绘制法线
-(void)drawNormals
{   //1.声明绘制光照法线数组
    GLKVector3 normalLineVertices[NUM_LINE_VERTS];
    
    //2.以每个顶点的坐标为起点，顶点坐标加上法向量的偏移值作为终点，更新法线显示数组
    //参数1.三角形数组
    //参数2：光源位置
    //参数3：法线显示的顶点数组
    SceneTrianglesNormalLinesUpdate(triangles, GLKVector3MakeWithArray(self.baseEffect.light0.position.v), normalLineVertices);
    
    //为extraBuffer 重新开辟空间
    [self.extraBuffer reinitWithAttribStride:sizeof(GLKVector3) numberOfVertices:NUM_LINE_VERTS bytes:normalLineVertices];
    
    //准备绘制数据
    [self.extraBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition numberOfCoordinates:3 attribOffset:0 shouldEnable:YES];

    /*
     指示是否使用常量颜色的布尔值。
     如果该值设置为gl_true，然后存储在设置属性的值为每个顶点的颜色值。如果该值设置为gl_false，那么你的应用将使glkvertexattribcolor属性提供每顶点颜色数据。默认值是gl_false。
     */
    self.extraEffect.useConstantColor = GL_TRUE;
    //设置光源颜色为绿色，画顶点发现
    self.extraEffect.constantColor = GLKVector4Make(0.0f, 1.0f, 0.0f, 1.0f);
    
    //准备绘制-绿色的法线
    [self.extraEffect prepareToDraw];
    
    //绘制线段
    [self.extraBuffer drawArrayWithMode:GL_LINES startVertexIndex:0 numberOfVertices:NUM_NORMAL_LINE_VERTS];
    
    //设置光源颜色为黄色，并且画光源
    //red+green = yellow
    self.extraEffect.constantColor = GLKVector4Make(1.0f, 1.0f, 0.0f, 1.0f);
    
    //准备绘制-黄色的光源方向线
    [self.extraEffect prepareToDraw];
    
    //(NUM_LINE_VERTS - NUM_NORMAL_LINE_VERTS) = 2 .2点确定一条线,绘制最后两条光源线
    [self.extraBuffer drawArrayWithMode:GL_LINES startVertexIndex:NUM_NORMAL_LINE_VERTS numberOfVertices:(NUM_LINE_VERTS - NUM_NORMAL_LINE_VERTS)];
}

//更新法向量
-(void)updateNormals
{
    if (self.shouldUseFaceNormals) {
        //更新每个点的平面法向量
        SceneTrianglesUpdateFaceNormals(triangles);
    }else {
        
        //通过平均值求出每一个点的法向量
        SceneTrianglesUpdateVertexNormals(triangles);
    }
    //重新渲染
    [self.vertexBuffer reinitWithAttribStride:sizeof(SceneVertex) numberOfVertices:sizeof(triangles)/sizeof(SceneVertex) bytes:triangles];
}

#pragma mark --Set
-(void)setCentexVertexHeight:(GLfloat)centexVertexHeight
{
    _centexVertexHeight = centexVertexHeight;
    
    //更新顶点E
    SceneVertex newVertexE = vertexE;
    newVertexE.position.z = _centexVertexHeight;
    
    //同时需要更新与顶点E相关的顶点，不然无效
    triangles[2] = SceneTriangleMake(vertexD, vertexB, newVertexE);
    triangles[3] = SceneTriangleMake(newVertexE, vertexB, vertexF);
    triangles[4] = SceneTriangleMake(vertexD, newVertexE, vertexH);
    triangles[5] = SceneTriangleMake(newVertexE, vertexF, vertexH);
    
   //然后更新法线
    [self updateNormals];
    
}

-(void)setShouldUseFaceNormals:(BOOL)shouldUseFaceNormals
{
    if (shouldUseFaceNormals != _shouldUseFaceNormals) {
        
        _shouldUseFaceNormals = shouldUseFaceNormals;
        
        [self updateNormals];
    }
    
}

#pragma makr --UI Change
//绘制屏幕法线
- (IBAction)takeShouldUseFaceNormals:(UISwitch *)sender {
    self.shouldUseFaceNormals = sender.isOn;
}

//绘制法线
- (IBAction)takeShouldDrawNormals:(UISwitch *)sender {
    
     self.shouldDrawNormals = sender.isOn;
}

//改变Z的高度
- (IBAction)changeCenterVertexHeight:(UISlider *)sender {
  
    self.centexVertexHeight = sender.value;
}


@end
