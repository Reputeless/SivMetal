//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include "CWindow.hpp"

namespace siv
{
	ISivMetalWindow* ISivMetalWindow::Create()
	{
		return new CWindow;
	}
}
