//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include <metal_stdlib>
# include "ShaderTypes.hpp"
using namespace metal;

// 頂点シェーダから rasterization ステージに送るデータ
struct RasterizerData
{
    float4 clipSpacePosition [[position]]; // クリップスペース座標（[[position]] attribute を使用）
    float4 color; // 色（補間される）
};

// 頂点シェーダ用の関数
vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]], // 頂点番号
			 // セットされた頂点データ [[buffer(0)]]
			 constant Vertex *vertices [[buffer(VertexInputIndex::Vertices)]],
			 // セットされた描画領域の解像度 [[buffer(1)]]
			 constant float2& viewportSize [[buffer(VertexInputIndex::ViewportSize)]])
{
	// 各頂点について、スクリーン座標をクリップスペース座標に変換
	float2 pixelSpacePosition = vertices[vertexID].position.xy;
	float2 pos = (pixelSpacePosition / (viewportSize * 0.5f)) - 1.0f;

	RasterizerData out;
	out.clipSpacePosition = float4(pos.x, -pos.y, 0.0f, 1.0f);
	out.color = vertices[vertexID].color;
	return out;
}

// フラグメントシェーダ用の関数
// [[stage_in]] attribute は、このデータが rasterization ステージから送られてくることを表す
fragment float4
fragmentShader(RasterizerData in [[stage_in]])
{
	return in.color;
}
