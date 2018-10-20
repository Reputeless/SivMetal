//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include <string>
# include "SivMetal/SivMetalEngine.hpp"
# include "SivMetal/System/ISystem.hpp"
# include "SivMetal/Window/IWindow.hpp"

namespace siv
{
	namespace System
	{
		bool Update()
		{
			return SivMetalEngine::GetSystem()->update();
		}
		
		int FrameCount()
		{
			return SivMetalEngine::GetSystem()->frameCount();
		}
	}
	
	namespace Window
	{
		void SetTitle(const std::string& title)
		{
			SivMetalEngine::GetWindow()->setTitle(title);
		}
	}
}
