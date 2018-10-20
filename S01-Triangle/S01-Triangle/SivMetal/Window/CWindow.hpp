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
# include "IWindow.hpp"

namespace siv
{
	class CWindow : public ISivMetalWindow
	{
	private:

		void* m_window;

	public:

		CWindow();

		~CWindow() override;

		bool init(void* pWindow) override;
		
		void setTitle(const std::string& title) override;
	};
}
