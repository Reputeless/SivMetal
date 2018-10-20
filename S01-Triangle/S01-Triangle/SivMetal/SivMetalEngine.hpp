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
# include <cassert>

namespace siv
{
	class ISivMetalSystem;
	class ISivMetalWindow;
	
	template <class Interface>
	class SivMetalComponent
	{
	private:
		
		Interface* pInterface = nullptr;
		
	public:
		
		SivMetalComponent()
			: pInterface(Interface::Create()) {}
		
		~SivMetalComponent()
		{
			assert(pInterface == nullptr);
		}
		
		Interface* get()
		{
			return pInterface;
		}
		
		void release()
		{
			delete pInterface;
			
			pInterface = nullptr;
		}
	};

	class SivMetalEngine
	{
	private:
		
		inline static SivMetalEngine* pEngine = nullptr;
		
		SivMetalComponent<ISivMetalSystem> m_system;
		
		SivMetalComponent<ISivMetalWindow> m_window;
		
	public:
		
		SivMetalEngine();
		
		~SivMetalEngine();
		
		static bool isActive()
		{
			return pEngine != nullptr;
		}
		
		static ISivMetalSystem* GetSystem()
		{
			return pEngine->m_system.get();
		}
		
		static ISivMetalWindow* GetWindow()
		{
			return pEngine->m_window.get();
		}
	};
}
