//-----------------------------------------------
//
//	This file is part of the SivMetal.
//
//	Copyright (c) 2018 Ryo Suzuki
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

# include "CSystem.hpp"

namespace siv
{
	ISivMetalSystem* ISivMetalSystem::Create()
	{
		return new CSystem;
	}
}
