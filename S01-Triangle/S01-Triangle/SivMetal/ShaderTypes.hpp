//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# pragma once
# include <simd/simd.h>

//
// このヘッダは .metal と Objective-C++ どちらからもインクルードできる
//

// 頂点シェーダにセットするデータのバッファ番号
struct VertexInputIndex
{
	enum
	{
		Vertices,     // 0
		ViewportSize, // 1
	};
};

// 頂点データ
struct Vertex
{
	simd::float2 position;  // 2D 座標
    simd::float4 color;     // RGBA カラー
};
