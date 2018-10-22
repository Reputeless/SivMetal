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
# import <array>
# import <vector>
# import <type_traits>
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

static AppDelegate *instance = nil;

class VertexBufferManager
{
private:
	
	// Triple buffering
	static constexpr size_t MaxInflightBuffers = 3;
	
	// MTLBuffer に格納する最大の頂点個数
	static constexpr size_t MaxVertices = 16384;
	
	// 描画する頂点データ
	std::vector<Vertex> m_vertices;
	
	dispatch_semaphore_t m_frameBoundarySemaphore = dispatch_semaphore_create(MaxInflightBuffers);
	
	size_t m_currentVertexBufferIndex = 0;
	
	// バッファ
	std::array<id<MTLBuffer>, 3> m_vertexBuffers;
	
public:
	
	void init(id<MTLDevice> device)
	{
		for(size_t i = 0; i < MaxInflightBuffers; ++i)
		{
			m_vertexBuffers[i] = [device newBufferWithLength:(sizeof(Vertex) * MaxVertices)
													 options:MTLResourceStorageModeShared];
		}
	}
	
	size_t update()
	{
		// Wait until the inflight command buffer has completed its work
		dispatch_semaphore_wait(m_frameBoundarySemaphore, DISPATCH_TIME_FOREVER);
		
		++m_currentVertexBufferIndex %= MaxInflightBuffers;
		
		const size_t num_vertices = m_vertices.size();
		
		memcpy(m_vertexBuffers[m_currentVertexBufferIndex].contents,
			   m_vertices.data(), (sizeof(Vertex) * num_vertices));
		
		m_vertices.clear();
		
		return num_vertices;
	}
	
	auto getCurrentBuffer() const
	{
		return m_vertexBuffers[m_currentVertexBufferIndex];
	}
	
	dispatch_semaphore_t getSemaphore() const
	{
		return m_frameBoundarySemaphore;
	}
	
	Vertex* prepare(size_t size)
	{
		if ((m_vertices.size() + size) > MaxVertices)
		{
			return nullptr;
		}
		
		m_vertices.resize(m_vertices.size() + size);
		
		return m_vertices.data() + (m_vertices.size() - size);
	}
};

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
	
	// 画面をクリアする色
	MTLClearColor clearColor;
	
	VertexBufferManager vertexBufferManager;
	
} siv;

@implementation AppDelegate

+ (AppDelegate *)sharedAppDelegate
{
	return instance;
}

// アプリケーションの初期化
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"#SivMetal# (1) applicationDidFinishLaunching");

	instance = self;
	
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
	[siv.mtkView setSampleCount:4];
	// drawable クリア時の色を設定する (RGBA)
	siv.clearColor = MTLClearColorMake(11/255.0, 22/255.0, 33/255.0, 1.0);
	[siv.mtkView setClearColor:siv.clearColor];
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
	
	siv.vertexBufferManager.init(siv.device);
	
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

// 描画処理
- (void)draw
{
	const size_t num_vertices = siv.vertexBufferManager.update();
	
	@autoreleasepool
	{
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
			
			if (num_vertices)
			{
				// 頂点シェーダ用のデータ [[buffer(0)]] をセット
				[renderCommandEncoder setVertexBuffer:siv.vertexBufferManager.getCurrentBuffer()
											   offset:0
											  atIndex:VertexInputIndex::Vertices];
				
				// 頂点シェーダ用のデータ [[buffer(1)]] をセット
				[renderCommandEncoder setVertexBytes:&viewportSize
											  length:sizeof(viewportSize)
											 atIndex:VertexInputIndex::ViewportSize];
				
				// セットされた頂点データを使って頂点を描画
				[renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangle
										 vertexStart:0
										 vertexCount:num_vertices];
			}
			
			// RenderCommandEncoder によるコマンド登録の終了
			[renderCommandEncoder endEncoding];
		}
		
		// 現在の drawable を表示させるコマンドを CommandBuffer に登録
		[commandBuffer presentDrawable:siv.mtkView.currentDrawable];
		
		__weak dispatch_semaphore_t semaphore = siv.vertexBufferManager.getSemaphore();
		[commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer)
		{
			// GPU work is complete
			// Signal the semaphore to start the CPU work
			dispatch_semaphore_signal(semaphore);
		}];
		
		// GPU に CommandBuffer を実行してもらう
		[commandBuffer commit];
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
	using int8	= std::int8_t;
	using int16	= std::int16_t;
	using int32	= std::int32_t;
	using int64	= std::int64_t;
	using uint8	= std::uint8_t;
	using uint16	= std::uint16_t;
	using uint32	= std::uint32_t;
	using uint64	= std::uint64_t;
	
	namespace Math
	{
		inline constexpr double Pi = 3.1415926535897932385;

		inline constexpr float PiF = 3.1415926535897932385f;

		inline constexpr double TwoPi = Pi * 2.0;

		inline constexpr float TwoPiF = PiF * 2.0f;
	}
	
	struct Point
	{
		using value_type = int32;
		
		value_type x, y;
		
		Point() noexcept = default;
		
		constexpr Point(const Point&) noexcept = default;
		
		constexpr Point(int32 _x, int32 _y) noexcept
		: x(_x)
		, y(_y) {}
		
		template <class X, class Y, std::enable_if_t<std::is_integral_v<X> && std::is_integral_v<Y>>* = nullptr>
		constexpr Point(X _x, Y _y) noexcept
		: x(static_cast<value_type>(_x))
		, y(static_cast<value_type>(_y)) {}
		
		template <class X, class Y, std::enable_if_t<!std::is_integral_v<X> || !std::is_integral_v<Y>>* = nullptr>
		constexpr Point(X _x, Y _y) noexcept = delete;
	};
	
	template <class Type>
	struct Vector2D
	{
		template <class U>
		using vector_type = Vector2D<U>;
		
		using value_type = Type;
		
		value_type x, y;
		
		Vector2D() noexcept = default;
		
		constexpr Vector2D(const Vector2D&) noexcept = default;
		
		template <class X, class Y>
		constexpr Vector2D(X _x, Y _y) noexcept
		: x(static_cast<value_type>(_x))
		, y(static_cast<value_type>(_y)) {}
		
		constexpr Vector2D(value_type _x, value_type _y) noexcept
		: x(_x)
		, y(_y) {}
		
		constexpr Vector2D(const Point& v) noexcept
		: x(static_cast<value_type>(v.x))
		, y(static_cast<value_type>(v.y)) {}
		
		template <class U>
		constexpr Vector2D(const Vector2D<U>& v) noexcept
		: x(static_cast<value_type>(v.x))
		, y(static_cast<value_type>(v.y)) {}
	};
	
	using Float2	= Vector2D<float>;
	using Vec2		= Vector2D<double>;
	
	struct ColorF
	{
		double r, g, b, a;
		
		ColorF() = default;
		
		constexpr ColorF(const ColorF& color) noexcept = default;
		
		explicit constexpr ColorF(double rgb, double _a = 1.0) noexcept
		: r(rgb)
		, g(rgb)
		, b(rgb)
		, a(_a) {}
		
		constexpr ColorF(double _r, double _g, double _b, double _a = 1.0) noexcept
		: r(_r)
		, g(_g)
		, b(_b)
		, a(_a) {}
	};
	
	void SetWindowTitle(const char* title);
	
	bool IsVisible();
	
	bool Update();
	
	int32 FrameCount();
	
	void SetBackground(double r, double g, double b, double a);
	
	void DrawTriangle(const Vec2& p0, const Vec2& p1, const Vec2& p2,
					  const ColorF& color);
	
	void DrawTriangle(const Vec2& p0, const Vec2& p1, const Vec2& p2,
					  const ColorF& c0, const ColorF& c1, const ColorF& c2);
	
	void DrawRect(const Vec2& pos, const Vec2& size, const ColorF& color);
}

namespace SivMetal
{
	void SetWindowTitle(const char* title)
	{
		[siv.window setTitle:[NSString stringWithUTF8String:title]];
	}
	
	bool IsVisible()
	{
		return [siv.window isVisible]
		&& ([siv.window occlusionState] & NSWindowOcclusionStateVisible);
	}
	
	bool Update()
	{
		if (!IsVisible())
		{
			// アプリケーションが不可視の場合 vSync しないので 16ms スリープ
			usleep(16 * 1000);
		}
		
		[[AppDelegate sharedAppDelegate] draw];
		
		// 描画内容を反映 (vSync)
		[siv.mtkView draw];
		
		return [[AppDelegate sharedAppDelegate] handleMessages];
	}
	
	int32 FrameCount()
	{
		return siv.frameCount;
	}
	
	void SetBackground(const ColorF& color)
	{
		siv.clearColor = MTLClearColorMake(color.r, color.g, color.b, color.a);
		[siv.mtkView setClearColor:siv.clearColor];
	}
	
	void DrawTriangle(const Vec2& p0, const Vec2& p1, const Vec2& p2,
					  const ColorF& color)
	{
		DrawTriangle(p0, p1, p2, color, color, color);
	}
	
	void DrawTriangle(const Vec2& p0, const Vec2& p1, const Vec2& p2,
					  const ColorF& c0, const ColorF& c1, const ColorF& c2)
	{
		Vertex* vtx = siv.vertexBufferManager.prepare(3);

		if (!vtx)
		{
			return;
		}

		vtx[0].position = simd::make_float2(p0.x, p0.y);
		vtx[0].color = simd::make_float4(c0.r, c0.g, c0.b, c0.a);
		vtx[1].position = simd::make_float2(p1.x, p1.y);
		vtx[1].color = simd::make_float4(c1.r, c1.g, c1.b, c1.a);
		vtx[2].position = simd::make_float2(p2.x, p2.y);
		vtx[2].color = simd::make_float4(c2.r, c2.g, c2.b, c2.a);
	}
	
	void DrawRect(const Vec2& pos, const Vec2& size, const ColorF& color)
	{
		Vertex* vtx = siv.vertexBufferManager.prepare(6);
		
		if (!vtx)
		{
			return;
		}
		
		const simd::float2 p0 = simd::make_float2(pos.x, pos.y);
		const simd::float2 p1 = simd::make_float2(pos.x + size.x, pos.y);
		const simd::float2 p2 = simd::make_float2(pos.x, pos.y + size.y);
		const simd::float2 p3 = simd::make_float2(pos.x + size.x, pos.y + size.y);
		const simd::float4 col = simd::make_float4(color.r, color.g, color.b, color.a);
		
		vtx[0].position = p0;
		vtx[1].position = p1;
		vtx[2].position = p2;
		vtx[3].position = p2;
		vtx[4].position = p1;
		vtx[5].position = p3;
		
		for (size_t i = 0; i < 6; ++i)
		{
			vtx[i].color = col;
		}
	}
	
	void DrawCircle(const Vec2& center, double r, const ColorF& color)
	{
		const uint32 quality = (r <= 5.0) ? (static_cast<uint32>(r + 4) * 2)
			: static_cast<uint32>(std::min(19 + (r - 5.0) / 2.2, 255.0));
		const size_t vertexSize = quality * 3;
		
		Vertex* vtx = siv.vertexBufferManager.prepare(vertexSize);
		
		if (!vtx)
		{
			return;
		}
		
		const float rd = Math::TwoPiF / (quality - 1);
		const simd::float2 c = simd::make_float2(center.x, center.y);
		const simd::float4 col = simd::make_float4(color.r, color.g, color.b, color.a);
		simd::float2 p0 = simd::make_float2(center.x, center.y - r);
		
		for (size_t i = 0; i < quality; ++i)
		{
			const float rad = rd * (i - 1.0f);
			const simd::float2 p1 = simd::make_float2(center.x + r * std::cos(rad),
													  center.y - r * std::sin(rad));
			vtx[i * 3 + 0].position = p0;
			vtx[i * 3 + 1].position = p1;
			vtx[i * 3 + 2].position = c;
			p0 = p1;
		}
		
		for (size_t i = 0; i < vertexSize; ++i)
		{
			vtx[i].color = col;
		}
	}
}

using SivMetal::int32;
using SivMetal::Vec2;
using SivMetal::ColorF;

void Main()
{
	// ウィンドウタイトルを変更する
	SivMetal::SetWindowTitle("SivMetal | Experimental Metal project for OpenSiv3D");
	
	// 背景色を変更する
	SivMetal::SetBackground(ColorF(0.8, 0.9, 1.0));
	
	while (SivMetal::Update())
	{
		for (int32 y = 0; y < 30; ++y)
		{
			for (int32 x = 0; x < 40; ++x)
			{
				// 長方形を描画
				SivMetal::DrawRect(Vec2(x * 20, y * 20), Vec2(15, 15), ColorF(0.5, 0.7, 0.9));
			}
		}
		
		// アニメーション
		const double t = 300.0 - (SivMetal::FrameCount() * 0.2);
		
		// 三角形を描画
		SivMetal::DrawTriangle(Vec2(400 + t, 100), Vec2(700, 500), Vec2(100, 500), ColorF(1, 0, 0, 1), ColorF(0, 1, 0, 1), ColorF(0, 0, 1, 1));
		
		// 半透明の三角形を描画
		SivMetal::DrawTriangle(Vec2(400 - t, 100), Vec2(700, 500), Vec2(100, 500), ColorF(1, 1, 1, 0.8));
		
		// 円を描画
		SivMetal::DrawCircle(Vec2(400, 120), 80, ColorF(1.0, 0.5, 0, 1));
	}
}
