// Flutter: Navigator / GoRouter equivalent
// PAGE ROUTING: stack-based push/pop + tab switching

import React, { createContext, useContext, useState, useCallback, useRef, ReactNode } from 'react'

export type TabKey = 'home' | 'plan' | 'calendar' | 'exercises'

export type ScreenKey =
  | 'home' | 'plan' | 'calendar' | 'exercises'
  | 'preWorkout' | 'workout' | 'rest' | 'summary'
  | 'historyDetail' | 'exerciseDetail'
  | 'planEdit' | 'createPlan' | 'editPlan'
  | 'exerciseCreate' | 'exerciseEdit'
  | 'settings'

// Flutter: RouteSettings equivalent
export interface StackEntry {
  screen: ScreenKey
  params?: Record<string, unknown>
}

// Flutter: PageTransitionsTheme — which direction the next screen enters from
export type TransitionDir = 'push' | 'pop' | 'tab'

interface NavValue {
  activeTab: TabKey
  stack: StackEntry[]
  currentScreen: ScreenKey
  params: Record<string, unknown>
  transitionDir: TransitionDir       // for Router to apply correct animation class
  transitionKey: number              // increment on each navigation to re-trigger animation
  // Flutter: Navigator.pushNamed
  push: (screen: ScreenKey, params?: Record<string, unknown>) => void
  // Flutter: Navigator.pop
  pop: () => void
  // Flutter: Navigator.pushReplacement
  replace: (screen: ScreenKey, params?: Record<string, unknown>) => void
  // Flutter: switch bottom tab (clears stack)
  setTab: (tab: TabKey) => void
}

const NavContext = createContext<NavValue | null>(null)

export function NavigationProvider({ children }: { children: ReactNode }) {
  // Flutter: setState / ValueNotifier<int> for selectedIndex
  const [activeTab, setActiveTab] = useState<TabKey>('home') // Flutter: setState
  const [stack, setStack] = useState<StackEntry[]>([])       // Flutter: NavigatorState stack
  const [transitionDir, setTransitionDir] = useState<TransitionDir>('push') // Flutter: setState
  const transitionKeyRef = useRef(0)
  const [transitionKey, setTransitionKey] = useState(0)

  const currentScreen: ScreenKey = stack.length > 0
    ? stack[stack.length - 1].screen
    : activeTab
  const params = (stack.length > 0 ? stack[stack.length - 1].params : {}) ?? {}

  const bumpKey = () => {
    transitionKeyRef.current += 1
    setTransitionKey(transitionKeyRef.current)
  }

  const push = useCallback((screen: ScreenKey, p?: Record<string, unknown>) => {
    setTransitionDir('push')
    setStack(s => [...s, { screen, params: p ?? {} }])
    bumpKey()
  }, [])

  const pop = useCallback(() => {
    setTransitionDir('pop')
    setStack(s => s.length > 1 ? s.slice(0, -1) : [])
    bumpKey()
  }, [])

  const replace = useCallback((screen: ScreenKey, p?: Record<string, unknown>) => {
    setTransitionDir('push')
    setStack(s => [...s.slice(0, -1), { screen, params: p ?? {} }])
    bumpKey()
  }, [])

  const setTab = useCallback((tab: TabKey) => {
    setTransitionDir('tab')
    setActiveTab(tab)
    setStack([])
    bumpKey()
  }, [])

  return (
    <NavContext.Provider value={{ activeTab, stack, currentScreen, params, transitionDir, transitionKey, push, pop, replace, setTab }}>
      {children}
    </NavContext.Provider>
  )
}

export function useNav() {
  const ctx = useContext(NavContext)
  if (!ctx) throw new Error('useNav outside NavigationProvider')
  return ctx
}
