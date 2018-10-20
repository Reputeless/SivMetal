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
	class ISivMetalWindow
	{
	public:

		static ISivMetalWindow* Create();

		virtual ~ISivMetalWindow() = default;

		virtual bool init(void* pWindow) = 0;
		
		virtual void setTitle(const std::string& title) = 0;
	};
}
