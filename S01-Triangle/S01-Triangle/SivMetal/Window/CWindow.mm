//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include <Cocoa/Cocoa.h>
# include "CWindow.hpp"

namespace siv
{
	CWindow::CWindow()
	{

	}

	CWindow::~CWindow()
	{
		
	}

	bool CWindow::init(void* pWindow)
	{
		m_window = pWindow;
		
		return true;
	}
	
	void CWindow::setTitle(const std::string& title)
	{
		[(__bridge NSWindow*)m_window setTitle:[NSString stringWithUTF8String:title.c_str()]];
	}
}
