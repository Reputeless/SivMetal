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
# import "ShaderTypes.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
// MainMenu.xib - Window
@property (weak) IBOutlet NSWindow *window;
@end

// Metal で描画できる view, MTKView のサブクラス
@interface SivMetalMTKView : MTKView
@end

@implementation AppDelegate
{
	// アプリケーションを続行するか
	bool _shouldKeepRunning;
	
	// mainLoop が完了したか
	bool _readyToTerminate;

	// 現在のフレームカウント
	int _frameCount;
	
	// GPU のインタフェース
	id<MTLDevice> _device;
	
	// view
	SivMetalMTKView *_view;
	
	// RenderPipelineState: レンダリングパイプラインを表現するオブジェクト
	id<MTLRenderPipelineState> _pipelineState;
	
	// CommandBuffer を発行するオブジェクト
	id<MTLCommandQueue> _commandQueue;
}

// アプリケーションの初期化
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"#SivMetal# applicationDidFinishLaunching");
	
	_shouldKeepRunning = true;
	_readyToTerminate = false;
	_frameCount = 0;

	// デフォルトの GPU デバイスを取得する
	_device = MTLCreateSystemDefaultDevice();
	
	// Metal 対応の view を作成する
	_view = [[SivMetalMTKView alloc] initWithFrame:CGRectMake(0, 0, 800, 600)
											device:_device];
	// ウィンドウに view を設定する
	[_window setContentView:_view];
	// ウィンドウタイトルを変更する
	[_window setTitle:@"SivMetal | Experimental Metal project for OpenSiv3D"];
	// ウィンドウを最前面に表示させる
	[NSApp activateIgnoringOtherApps:YES];
	[_window makeKeyAndOrderFront:self];
	
	// view の drawable のピクセルフォーマットを設定する
	[_view setColorPixelFormat:MTLPixelFormatBGRA8Unorm];
	// depthStencilTexture のフォーマットを設定する
	[_view setDepthStencilPixelFormat:MTLPixelFormatDepth32Float_Stencil8];
	// MSAA を設定する
	// 1, 4 はすべての macOS でサポートされている
	// 参考: https://developer.apple.com/documentation/metal/mtldevice/1433355-supportstexturesamplecount
	[_view setSampleCount:1];
	// drawable クリア時の色を設定する (RGBA)
	[_view setClearColor:MTLClearColorMake(0.8, 0.9, 1.0, 1.0)];
	// mainLoop から draw するための設定
	[_view setPaused:YES];

	// プロジェクト内の .metal 拡張子のシェーダファイルをすべてロードする
	id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
	// シェーダ関数 `vertexShader` をロードする
	id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
	// シェーダ関数 `fragmentShader` をロードする
	id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
	
	// RenderPipelineState を作成するための設定 (RenderPipelineDescriptor) を記述する
	MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	pipelineStateDescriptor.label = @"Simple Pipeline"; // ラベルをつけておくとデバッグ時に便利（任意）
	pipelineStateDescriptor.vertexFunction = vertexFunction; // 頂点シェーダの関数
	pipelineStateDescriptor.fragmentFunction = fragmentFunction; // フラグメントシェーダの関数
	pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat; // 出力先のフォーマット
	pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES; // アルファブレンディングのための設定
	pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
	pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
	pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
	pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
	pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
	pipelineStateDescriptor.rasterSampleCount = _view.sampleCount; // MSAA
	pipelineStateDescriptor.depthAttachmentPixelFormat = _view.depthStencilPixelFormat; // 深度フォーマット
	pipelineStateDescriptor.stencilAttachmentPixelFormat = _view.depthStencilPixelFormat; // ステンシルフォーマット

	// RenderPipelineState を作成する
	NSError *error = NULL;
	_pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
															 error:&error];
	if (!_pipelineState)
	{
		// RenderPipelineDescriptor の記述が間違っているとエラー
		NSLog(@"#SivMetal# Failed to created pipeline state, error %@", error);
		return;
	}
	
	// CommandQueue を作成。1 つのアプリケーションに 1 つ作るだけで良い
	_commandQueue = [_device newCommandQueue];
	
	// mainLoop を実行する
	[self performSelectorOnMainThread:@selector(mainLoop) withObject:nil waitUntilDone:NO];
}

// terminate が呼ばれた
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	NSLog(@"#SivMetal# applicationShouldTerminate");
	
	// handleMessages が false を返すようにする
	_shouldKeepRunning = false;
	
	if (_readyToTerminate)
	{
		NSLog(@"#SivMetal# (_readyToTerminate == true)");
		// mainLoop が終了していたらアプリケーションを終了
		return NSTerminateNow;
	}
	else
	{
		NSLog(@"#SivMetal# (_readyToTerminate == false)");
		// mainLoop が終了するまではアプリケーションを終了しない
		return NSTerminateCancel;
	}
}

// アプリケーションが終了
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSLog(@"#SivMetal# applicationWillTerminate");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	// ウィンドウが閉じられたときに自動的に terminate が呼ばれるようにする
	return YES;
}

// イベントを処理
- (bool)handleMessages
{
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
	
	return _shouldKeepRunning;
}

- (BOOL)isVisible
{
	return [_window isVisible]
		&& ([_window occlusionState] & NSWindowOcclusionStateVisible);
}

// 描画処理
- (void)draw
{
	@autoreleasepool
	{
		// アニメーション
		const float x = 300.0f - (_frameCount * 0.2f);
		
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
		id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
		commandBuffer.label = @"MyCommand"; // ラベルをつけておくとデバッグ時に便利（任意）

		// 現在の drawable texture から RenderPassDescriptor を作成
		MTLRenderPassDescriptor *renderPassDescriptor = _view.currentRenderPassDescriptor;
		
		if(renderPassDescriptor != nil)
		{
			// RenderPassDescriptor から RenderCommandEncoder を作成
			// RenderCommandEncoder によって、レンダリングコマンドが CommandBuffer に登録される
			id<MTLRenderCommandEncoder> renderCommandEncoder =
			[commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
			renderCommandEncoder.label = @"MyRenderCommandEncoder"; // ラベルをつけておくとデバッグ時に便利（任意）
			
			// 現在のウィンドウの解像度を取得
			simd::float2 viewportSize;
			viewportSize.x = [_view drawableSize].width;
			viewportSize.y = [_view drawableSize].height;

			// RenderCommandEncoder にビューポートを設定する
			[renderCommandEncoder setViewport:(MTLViewport){0, 0, viewportSize.x, viewportSize.y, -1.0, 1.0 }];
			
			// RenderPipelineState を設定する
			[renderCommandEncoder setRenderPipelineState:_pipelineState];
			
			// 頂点シェーダ用のデータ [[buffer(0)]] をセット
			// setVertexBytes で扱えるデータは 4kB 以下。大きなデータは setVertexBuffer を使う
			[renderCommandEncoder setVertexBytes:triangleVertices
										  length:sizeof(triangleVertices)
										 atIndex:VertexInputIndex::Vertices];
			
			// ウィンドウの表示スケーリングを考慮
			const float scale = [_window backingScaleFactor];;
			viewportSize.x /= scale;
			viewportSize.y /= scale;
			
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
		[commandBuffer presentDrawable:_view.currentDrawable];
		
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
		[_view draw];
	}
}

// メインループ
- (void)mainLoop
{
	NSLog(@"#SivMetal# mainLoop");
	
	// drawable を初期化
	[_view draw];
	
	while ([self handleMessages])
	{
		++_frameCount;
		
		[self draw];
	}
	
	NSLog(@"#SivMetal# ~mainLoop");
	
	_readyToTerminate = true;
	
	// applicationShouldTerminate を呼び出してアプリケーションの終了を通知
	[NSApp terminate:nil];
}

@end

@implementation SivMetalMTKView

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
