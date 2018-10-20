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
	class ISivMetalSystem
	{
	public:

		static ISivMetalSystem* Create();

		virtual ~ISivMetalSystem() = default;

		virtual bool init() = 0;
		
		virtual bool update() = 0;
		
		virtual void exit() = 0;
		
		virtual int frameCount() const = 0;
	};
}
