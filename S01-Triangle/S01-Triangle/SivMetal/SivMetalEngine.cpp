//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include "SivMetalEngine.hpp"
# include "System/ISystem.hpp"
# include "Window/IWindow.hpp"

namespace siv
{
	SivMetalEngine::SivMetalEngine()
	{
		pEngine = this;
	}
	
	SivMetalEngine::~SivMetalEngine()
	{
		m_window.release();
		m_system.release();
	}
}
