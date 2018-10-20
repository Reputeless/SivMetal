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
# include <string>

namespace siv
{
	namespace System
	{
		bool Update();
		
		void Exit();
		
		int FrameCount();
	}
	
	namespace Window
	{
		void SetTitle(const std::string& title);
	}
		
	void Draw();
}

using namespace siv;
