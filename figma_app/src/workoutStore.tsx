// Flutter: Provider / Riverpod StateNotifier equivalent
// Holds the entire active workout session — survives screen navigation

import React, { createContext, useContext, useState, useCallback, useRef, useEffect, ReactNode } from 'react'

export type SetStatus = 'pending' | 'current' | 'done' | 'skipped'
export type WorkoutPhase = 'idle' | 'active' | 'resting' | 'done'

export interface WorkoutSet {
  id: string
  weight: number      // planned (0 = bodyweight)
  reps: number        // planned
  status: SetStatus
  actualWeight?: number
  actualReps?: number
}

export interface WorkoutExercise {
  id: string
  name: string
  iconChar: string   // 2-char label for icon
  targetRest: number // seconds
  sets: WorkoutSet[]
}

interface WState {
  phase: WorkoutPhase
  exercises: WorkoutExercise[]
  elapsedSeconds: number       // total workout elapsed
  restElapsedSeconds: number   // current rest elapsed
  targetRestSeconds: number    // target rest duration
  currentExerciseId: string | null
  currentSetId: string | null
}

interface WActions {
  startWorkout: (exercises: WorkoutExercise[]) => void
  completeCurrentSet: () => void
  skipSet: (exerciseId: string, setId: string) => void
  selectSet: (exerciseId: string, setId: string) => void
  endRest: () => void
  earlyFinish: () => void
  abandonWorkout: () => void
}

const Ctx = createContext<(WState & WActions) | null>(null)

const INIT: WState = {
  phase: 'idle', exercises: [],
  elapsedSeconds: 0, restElapsedSeconds: 0, targetRestSeconds: 90,
  currentExerciseId: null, currentSetId: null,
}

// Find first pending set, optionally after a given position
function nextPending(
  exercises: WorkoutExercise[],
  afterExId?: string,
  afterSetId?: string
): { exerciseId: string; setId: string } | null {
  let passed = !afterExId
  for (const ex of exercises) {
    for (const s of ex.sets) {
      if (!passed) {
        if (ex.id === afterExId && s.id === afterSetId) passed = true
        continue
      }
      if (s.status === 'pending') return { exerciseId: ex.id, setId: s.id }
    }
  }
  return null
}

function markCurrent(
  exercises: WorkoutExercise[],
  exerciseId: string,
  setId: string
): WorkoutExercise[] {
  return exercises.map(ex => ({
    ...ex,
    sets: ex.sets.map(s =>
      ex.id === exerciseId && s.id === setId ? { ...s, status: 'current' as SetStatus } : s
    ),
  }))
}

export function WorkoutStoreProvider({ children }: { children: ReactNode }) {
  const [s, setS] = useState<WState>(INIT)
  const t0 = useRef(0)   // workout start timestamp
  const r0 = useRef(0)   // rest start timestamp

  // Flutter: Timer.periodic → elapsedSeconds
  useEffect(() => {
    if (s.phase !== 'active' && s.phase !== 'resting') return
    const iv = setInterval(() => {
      setS(prev => ({ ...prev, elapsedSeconds: Math.floor((Date.now() - t0.current) / 1000) }))
    }, 1000)
    return () => clearInterval(iv)
  }, [s.phase])

  // Flutter: Timer.periodic → restElapsedSeconds
  useEffect(() => {
    if (s.phase !== 'resting') return
    const iv = setInterval(() => {
      setS(prev => ({ ...prev, restElapsedSeconds: Math.floor((Date.now() - r0.current) / 1000) }))
    }, 1000)
    return () => clearInterval(iv)
  }, [s.phase])

  const startWorkout = useCallback((exercises: WorkoutExercise[]) => {
    t0.current = Date.now()
    const next = nextPending(exercises)
    setS({
      ...INIT,
      phase: 'active',
      exercises: next ? markCurrent(exercises, next.exerciseId, next.setId) : exercises,
      currentExerciseId: next?.exerciseId ?? null,
      currentSetId: next?.setId ?? null,
      targetRestSeconds: exercises[0]?.targetRest ?? 90,
    })
  }, [])

  const completeCurrentSet = useCallback(() => {
    setS(prev => {
      if (!prev.currentExerciseId || !prev.currentSetId) return prev
      const ex = prev.exercises.find(e => e.id === prev.currentExerciseId)
      const targetRest = ex?.targetRest ?? 90

      // Mark done
      const doneExercises = prev.exercises.map(e => ({
        ...e,
        sets: e.sets.map(set =>
          e.id === prev.currentExerciseId && set.id === prev.currentSetId
            ? { ...set, status: 'done' as SetStatus }
            : set
        ),
      }))

      const next = nextPending(doneExercises, prev.currentExerciseId, prev.currentSetId)
      r0.current = Date.now()
      return {
        ...prev,
        exercises: doneExercises,
        phase: 'resting',
        restElapsedSeconds: 0,
        targetRestSeconds: targetRest,
        currentExerciseId: next?.exerciseId ?? null,
        currentSetId: next?.setId ?? null,
      }
    })
  }, [])

  const skipSet = useCallback((exerciseId: string, setId: string) => {
    setS(prev => {
      const skipped = prev.exercises.map(ex => ({
        ...ex,
        sets: ex.sets.map(s =>
          ex.id === exerciseId && s.id === setId
            ? { ...s, status: 'skipped' as SetStatus }
            : s
        ),
      }))
      const next = nextPending(skipped)
      return {
        ...prev,
        exercises: next ? markCurrent(skipped, next.exerciseId, next.setId) : skipped,
        currentExerciseId: next?.exerciseId ?? null,
        currentSetId: next?.setId ?? null,
      }
    })
  }, [])

  const selectSet = useCallback((exerciseId: string, setId: string) => {
    setS(prev => {
      const reset = prev.exercises.map(ex => ({
        ...ex,
        sets: ex.sets.map(s =>
          ex.id === prev.currentExerciseId && s.id === prev.currentSetId && s.status === 'current'
            ? { ...s, status: 'pending' as SetStatus }
            : s
        ),
      }))
      return {
        ...prev,
        exercises: markCurrent(reset, exerciseId, setId),
        currentExerciseId: exerciseId,
        currentSetId: setId,
        phase: 'active',
      }
    })
  }, [])

  const endRest = useCallback(() => {
    setS(prev => {
      if (!prev.currentExerciseId || !prev.currentSetId) return { ...prev, phase: 'active' }
      return {
        ...prev,
        phase: 'active',
        exercises: markCurrent(prev.exercises, prev.currentExerciseId, prev.currentSetId),
      }
    })
  }, [])

  const earlyFinish = useCallback(() => {
    setS(prev => ({
      ...prev,
      phase: 'done',
      exercises: prev.exercises.map(ex => ({
        ...ex,
        sets: ex.sets.map(s =>
          s.status === 'pending' || s.status === 'current'
            ? { ...s, status: 'skipped' as SetStatus }
            : s
        ),
      })),
    }))
  }, [])

  const abandonWorkout = useCallback(() => setS(INIT), [])

  return (
    <Ctx.Provider value={{ ...s, startWorkout, completeCurrentSet, skipSet, selectSet, endRest, earlyFinish, abandonWorkout }}>
      {children}
    </Ctx.Provider>
  )
}

export function useWorkout() {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useWorkout outside WorkoutStoreProvider')
  return ctx
}

// Flutter: DateTimeUtils.formatDuration
export function fmtTime(sec: number): string {
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = sec % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
}
