//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include <iostream>
# include "SivMetal.hpp"

void Main()
{
	Window::SetTitle("Siv3D App");
	
	while (System::Update())
	{
		std::cout << System::FrameCount() << '\n';
		
		Draw();
	}
}
