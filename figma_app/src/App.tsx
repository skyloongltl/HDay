// Flutter: MaterialApp + Navigator + BottomNavigationBar shell
// Phone frame is for browser prototype only — Flutter renders full-screen

import { NavigationProvider, useNav } from './navigation'
import { WorkoutStoreProvider } from './workoutStore'

// Screens — tabs
import HomeScreen from './screens/HomeScreen'
import PlanScreen from './screens/PlanScreen'
import CalendarScreen from './screens/CalendarScreen'
import ExerciseLibraryScreen from './screens/ExerciseLibraryScreen'

// Screens — workout flow (immersive, no BottomNav)
import PreWorkoutScreen from './screens/PreWorkoutScreen'
import WorkoutScreen from './screens/WorkoutScreen'
import RestScreen from './screens/RestScreen'
import WorkoutSummaryScreen from './screens/WorkoutSummaryScreen'

// Screens — secondary / detail
import HistoryDetailScreen from './screens/HistoryDetailScreen'
import ExerciseDetailScreen from './screens/ExerciseDetailScreen'
import PlanEditScreen from './screens/PlanEditScreen'
import CreateEditPlanScreen from './screens/CreateEditPlanScreen'
import ExerciseCreateEditScreen from './screens/ExerciseCreateEditScreen'
import SettingsScreen from './screens/SettingsScreen'

// Flutter: Navigator.build — renders current route from stack
// Animation: screen-level transitions via CSS classes (.screen-push / .screen-pop / .screen-tab)
function Router() {
  const { currentScreen, transitionDir, transitionKey } = useNav()

  const screenMap: Record<string, React.ReactNode> = {
    home:           <HomeScreen />,
    plan:           <PlanScreen />,
    calendar:       <CalendarScreen />,
    exercises:      <ExerciseLibraryScreen />,
    preWorkout:     <PreWorkoutScreen />,
    workout:        <WorkoutScreen />,
    rest:           <RestScreen />,
    summary:        <WorkoutSummaryScreen />,
    historyDetail:  <HistoryDetailScreen />,
    exerciseDetail: <ExerciseDetailScreen />,
    planEdit:       <PlanEditScreen />,
    createPlan:     <CreateEditPlanScreen />,
    editPlan:       <CreateEditPlanScreen />,
    exerciseCreate: <ExerciseCreateEditScreen />,
    exerciseEdit:   <ExerciseCreateEditScreen />,
    settings:       <SettingsScreen />,
  }

  const dirClass =
    transitionDir === 'push' ? 'screen-push' :
    transitionDir === 'pop'  ? 'screen-pop'  :
    'screen-tab'

  // key forces remount → re-triggers CSS animation on every navigation
  return (
    <div
      key={transitionKey}
      className={dirClass}
      style={{ width: '100%', height: '100%' }}
    >
      {screenMap[currentScreen] ?? <HomeScreen />}
    </div>
  )
}

// Flutter: PhoneFrame is prototype-only — remove in Flutter implementation
function PhoneFrame({ children }: { children: React.ReactNode }) {
  return (
    // Browser chrome: centered page background
    <div style={{
      minHeight: '100vh',
      display: 'flex',            // Flutter: Center
      alignItems: 'center',
      justifyContent: 'center',
      background: '#b8c4cc',
      padding: '24px 16px',
    }}>
      {/* Phone shell — Flutter: remove this wrapper entirely */}
      <div style={{
        width: 390,
        height: 844,
        border: '10px solid #18202a',
        borderRadius: 52,
        overflow: 'hidden',
        position: 'relative',
        boxShadow: [
          '0 0 0 1px #0e1318',
          '0 40px 100px rgba(0,0,0,0.55)',
          'inset 0 0 0 1.5px #2e3a46',
        ].join(', '),
        flexShrink: 0,
        // Side button notch marks
        background: '#18202a',
      }}>
        {/* Dynamic island notch area (top) */}
        <div style={{
          position: 'absolute',
          top: 0, left: '50%',
          transform: 'translateX(-50%)',
          width: 120, height: 0,
          zIndex: 20,
          pointerEvents: 'none',
        }} />

        {/* Screen content */}
        <div style={{
          position: 'absolute',
          inset: 0,
          overflow: 'hidden',
          borderRadius: 42,
        }}>
          {children}
        </div>
      </div>
    </div>
  )
}

export default function App() {
  return (
    <NavigationProvider>
      <WorkoutStoreProvider>
        <PhoneFrame>
          <Router />
        </PhoneFrame>
      </WorkoutStoreProvider>
    </NavigationProvider>
  )
}
