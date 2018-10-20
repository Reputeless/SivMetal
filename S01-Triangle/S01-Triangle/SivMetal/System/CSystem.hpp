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
# include "ISystem.hpp"

namespace siv
{
	class CSystem : public ISivMetalSystem
	{
	private:

		// 現在のフレームカウント
		int m_frameCount = 0;
		
		// アプリケーションを続行するか
		bool m_shouldKeepRunning = true;

	public:

		CSystem();

		~CSystem() override;
		
		bool init() override;

		bool update() override;
		
		void exit() override;
		
		int frameCount() const override;
	};
}
