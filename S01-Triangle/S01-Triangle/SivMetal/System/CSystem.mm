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
# include "CSystem.hpp"

namespace siv
{
	void PollEvents(bool* shouldKeepRunning);
	
	CSystem::CSystem()
	{

	}

	CSystem::~CSystem()
	{
		
	}
	
	bool CSystem::init()
	{
		
		return true;
	}

	bool CSystem::update()
	{
		++m_frameCount;
		
		@autoreleasepool
		{
			for (;;)
			{
				NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny
													untilDate:[NSDate distantPast]
													   inMode:NSDefaultRunLoopMode
													  dequeue:YES];
				if (event == nil)
				{
					break;
				}
				
				[NSApp sendEvent:event];
			}
		}
		
		PollEvents(&m_shouldKeepRunning);
		
		return m_shouldKeepRunning;
	}
	
	void CSystem::exit()
	{
		
	}
	
	int CSystem::frameCount() const
	{
		return m_frameCount;
	}
}
