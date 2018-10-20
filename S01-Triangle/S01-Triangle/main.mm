//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# import <Cocoa/Cocoa.h>
# import <Metal/Metal.h>
# import <MetalKit/MetalKit.h>
# import "ShaderTypes.hpp"

@interface AppDelegate : NSObject <NSApplicationDelegate>
// MainMenu.xib - Window
@property (weak) IBOutlet NSWindow *window;

+ (AppDelegate *)sharedAppDelegate;
@end

// Metal で描画できる view, MTKView のサブクラス
@interface AppMTKView : MTKView
@end

void Main();

struct InternalSivMetalData
{
	// アプリケーションを続行するか
	bool shouldKeepRunning = true;
	
	// mainLoop が完了したか
	bool readyToTerminate = false;
	
	// 現在のフレームカウント
	int frameCount = 0;
	
	// GPU のインタフェース
	id<MTLDevice> device;
	
	// ウィンドウ
	NSWindow* window;
	
	// view
	AppMTKView* mtkView;
	
	// RenderPipelineState: レンダリングパイプラインを表現するオブジェクト
	id<MTLRenderPipelineState> pipelineState;
	
	// CommandBuffer を発行するオブジェクト
	id<MTLCommandQueue> commandQueue;
} siv;

@implementation AppDelegate

+ (AppDelegate *)sharedAppDelegate
{
	return (AppDelegate *)[NSApplication sharedApplication].delegate;
}

// アプリケーションの初期化
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"#SivMetal# (1) applicationDidFinishLaunching");

	// デフォルトの GPU デバイスを取得する
	siv.device = MTLCreateSystemDefaultDevice();
	
	// Metal 対応の view を作成する
	siv.mtkView = [[AppMTKView alloc] initWithFrame:CGRectMake(0, 0, 800, 600)
											device:siv.device];
	
	// ウィンドウ
	siv.window = _window;
	
	// ウィンドウに view を設定する
	[siv.window setContentView:siv.mtkView];
	// ウィンドウを最前面に表示させる
	[NSApp activateIgnoringOtherApps:YES];
	[siv.window makeKeyAndOrderFront:self];
	
	// view の drawable のピクセルフォーマットを設定する
	[siv.mtkView setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
	// depthStencilTexture のフォーマットを設定する
	[siv.mtkView setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
	// MSAA を設定する
	// 1, 4 はすべての macOS でサポートされている
	// 参考: https://developer.apple.com/documentation/metal/mtldevice/1433355-supportstexturesamplecount
	[siv.mtkView setSampleCount:1];
	// drawable クリア時の色を設定する (RGBA)
	[siv.mtkView setClearColor:MTLClearColorMake(0.8, 0.9, 1.0, 1.0)];
	// mainLoop から draw するための設定
	[siv.mtkView setPaused:YES];

	// プロジェクト内の .metal 拡張子のシェーダファイルをすべてロードする
	id<MTLLibrary> defaultLibrary = [siv.device newDefaultLibrary];
	// シェーダ関数 `vertexShader` をロードする
	id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
	// シェーダ関数 `fragmentShader` をロードする
	id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
	
	// RenderPipelineState を作成するための設定 (RenderPipelineDescriptor) を記述する
	MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineStateDescriptor.label = @"Simple Pipeline"; // ラベルをつけておくとデバッグ時に便利（任意）
	pipelineStateDescriptor.vertexFunction = vertexFunction; // 頂点シェーダの関数
	pipelineStateDescriptor.fragmentFunction = fragmentFunction; // フラグメントシェーダの関数
	pipelineStateDescriptor.colorAttachments[0].pixelFormat = siv.mtkView.colorPixelFormat; // 出力先のフォーマット
	pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES; // アルファブレンディングのための設定
	pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
	pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
	pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
	pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
	pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
	pipelineStateDescriptor.rasterSampleCount = siv.mtkView.sampleCount; // MSAA
	pipelineStateDescriptor.depthAttachmentPixelFormat = siv.mtkView.depthStencilPixelFormat; // 深度フォーマット
	pipelineStateDescriptor.stencilAttachmentPixelFormat = siv.mtkView.depthStencilPixelFormat; // ステンシルフォーマット

	// RenderPipelineState を作成する
	NSError *error = NULL;
	siv.pipelineState = [siv.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
															 error:&error];
	if (!siv.pipelineState)
	{
		// RenderPipelineDescriptor の記述が間違っているとエラー
		NSLog(@"#SivMetal# Failed to created pipeline state, error %@", error);
		return;
	}
	
	// CommandQueue を作成。1 つのアプリケーションに 1 つ作るだけで良い
	siv.commandQueue = [siv.device newCommandQueue];
	
	// mainLoop を実行する
	[self performSelectorOnMainThread:@selector(mainLoop) withObject:nil waitUntilDone:NO];
}

// terminate が呼ばれた
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	NSLog(@"#SivMetal# applicationShouldTerminate");
	
	// handleMessages が false を返すようにする
	siv.shouldKeepRunning = false;
	
	if (siv.readyToTerminate)
	{
		NSLog(@"#SivMetal# (readyToTerminate == true)");
		// mainLoop が終了していたらアプリケーションを終了
		return NSTerminateNow;
	}
	else
	{
		NSLog(@"#SivMetal# (readyToTerminate == false)");
		// mainLoop が終了するまではアプリケーションを終了しない
		return NSTerminateCancel;
	}
}

// アプリケーションが終了
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSLog(@"#SivMetal# (4) applicationWillTerminate");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	// ウィンドウが閉じられたときに自動的に terminate が呼ばれるようにする
	return YES;
}

// イベントを処理
- (bool)handleMessages
{
	++siv.frameCount;
	
	@autoreleasepool
	{
		for (;;)
		{
			NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
												untilDate:[NSDate distantPast]
												   inMode:NSDefaultRunLoopMode
												  dequeue:YES];
			if (event == nil)
			{
				break;
			}
			
			[NSApp sendEvent:event];
		}
	}
	
	return siv.shouldKeepRunning;
}

- (BOOL)isVisible
{
	return [siv.window isVisible]
		&& ([siv.window occlusionState] & NSWindowOcclusionStateVisible);
}

// 描画処理
- (void)draw
{
	@autoreleasepool
	{
		// アニメーション
		const float x = 300.0f - (siv.frameCount * 0.2f);
		
		// 三角形を描くための頂点データ
		// アライメントされたベクトルデータ simf::float2, simd::float4 を
		// simd::make_float2(), simd::make_float4() で作成する
		const Vertex triangleVertices[] =
		{
			// 2D 座標,                         RGBA カラー
			{ simd::make_float2(400 + x, 100), simd::make_float4(1, 0, 0, 1) },
			{ simd::make_float2(700, 500),     simd::make_float4(0, 1, 0, 1) },
			{ simd::make_float2(100, 500),     simd::make_float4(0, 0, 1, 1) },
		};
		
		// 現在の drawable に使う、新しいレンダーパスのための CommandBuffer を作成
		id<MTLCommandBuffer> commandBuffer = [siv.commandQueue commandBuffer];
		commandBuffer.label = @"MyCommand"; // ラベルをつけておくとデバッグ時に便利（任意）

		// 現在の drawable texture の RenderPassDescriptor を取得する
		MTLRenderPassDescriptor *renderPassDescriptor = siv.mtkView.currentRenderPassDescriptor;
		
		if(renderPassDescriptor != nil)
		{
			// RenderPassDescriptor から RenderCommandEncoder を作成
			// RenderCommandEncoder によって、レンダリングコマンドが CommandBuffer に登録される
			id<MTLRenderCommandEncoder> renderCommandEncoder =
			[commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
			renderCommandEncoder.label = @"MyRenderCommandEncoder"; // ラベルをつけておくとデバッグ時に便利（任意）
			
			// 現在のウィンドウの解像度を取得
			simd::float2 viewportSize;
			viewportSize.x = [siv.mtkView drawableSize].width;
			viewportSize.y = [siv.mtkView drawableSize].height;

			// RenderCommandEncoder にビューポートを設定する
			[renderCommandEncoder setViewport:(MTLViewport){0, 0, viewportSize.x, viewportSize.y, -1.0, 1.0 }];
			
			// RenderPipelineState を設定する
			[renderCommandEncoder setRenderPipelineState:siv.pipelineState];
			
			// ウィンドウの表示スケーリングを考慮
			const float scale = [siv.window backingScaleFactor];;
			viewportSize.x /= scale;
			viewportSize.y /= scale;
			
			// 頂点シェーダ用のデータ [[buffer(0)]] をセット
			// setVertexBytes で扱えるデータは 4kB 以下。大きなデータは setVertexBuffer を使う
			[renderCommandEncoder setVertexBytes:triangleVertices
										  length:sizeof(triangleVertices)
										 atIndex:VertexInputIndex::Vertices];
			
			// 頂点シェーダ用のデータ [[buffer(1)]] をセット
			[renderCommandEncoder setVertexBytes:&viewportSize
										  length:sizeof(viewportSize)
										 atIndex:VertexInputIndex::ViewportSize];
			
			// セットされた頂点データを使って 3 個の頂点を描画
			[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle
									 vertexStart:0
									 vertexCount:3];
			
			// RenderCommandEncoder によるコマンド登録の終了
			[renderCommandEncoder endEncoding];
		}
		
		// 現在の drawable を表示させるコマンドを CommandBuffer に登録
		[commandBuffer presentDrawable:siv.mtkView.currentDrawable];
		
		// GPU に CommandBuffer を実行してもらう
		[commandBuffer commit];
		
		// CommandBuffer の実行が完了するまで待機
		[commandBuffer waitUntilCompleted];
		
		if (![self isVisible])
		{
			// アプリケーションが不可視の場合 vSync しないので 16ms スリープ
			usleep(16 * 1000);
		}
		
		// 描画内容を反映 (vSync)
		[siv.mtkView draw];
	}
}

// メインループ
- (void)mainLoop
{
	NSLog(@"#SivMetal# (2) mainLoop");
	
	// drawable を初期化
	[siv.mtkView draw];
	
	Main();
	
	NSLog(@"#SivMetal# (3) ~mainLoop");
	
	siv.readyToTerminate = true;
	
	// applicationShouldTerminate を呼び出してアプリケーションの終了を通知
	[NSApp terminate:nil];
}

@end

@implementation AppMTKView

- (BOOL)isOpaque
{
	return YES;
}

- (BOOL)canBecomeKey
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

// 左クリックされた
- (void)mouseDown:(NSEvent *)event
{
	NSLog(@"#SivMetal# MouseL.Down");
}

// 右クリックされた
- (void)rightMouseDown:(NSEvent *)event
{
	NSLog(@"#SivMetal# MouseR.Down");
}

@end

int main(int argc, const char *argv[])
{
	return NSApplicationMain(argc, argv);
}

namespace SivMetal
{
	void SetWindowTitle(const char* title);

	bool Update();
	
	void Draw();
}

namespace SivMetal
{
	void SetWindowTitle(const char* title)
	{
		[siv.window setTitle:[NSString stringWithUTF8String:title]];
	}
	
	bool Update()
	{
		return [[AppDelegate sharedAppDelegate] handleMessages];
	}
	
	void Draw()
	{
		return [[AppDelegate sharedAppDelegate] draw];
	}
}

void Main()
{
	// ウィンドウタイトルを変更する
	SivMetal::SetWindowTitle("SivMetal | Experimental Metal project for OpenSiv3D");
	
	while (SivMetal::Update())
	{
		SivMetal::Draw();
	}
}
