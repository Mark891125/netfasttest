"use client";

import { useState, useEffect, Dispatch, SetStateAction } from "react";

/**
 * A hook to manage localStorage state with SSR safety.
 * @param key localStorage key
 * @param defaultValue default value before loaded
 */
export default function useLocalStorage<T>(
  key: string,
  defaultValue: T
): [T, Dispatch<SetStateAction<T>>] {
  const [state, setState] = useState<T>(defaultValue);
  const [isInitialized, setIsInitialized] = useState(false);

  // 从 localStorage 读取值（只在客户端执行一次）
  useEffect(() => {
    if (isInitialized) return;

    try {
      const stored = window.localStorage.getItem(key);
      if (stored !== null) {
        // 处理不同类型的值
        if (typeof defaultValue === "boolean") {
          setState((stored === "true") as T);
        } else if (typeof defaultValue === "number") {
          setState(Number(stored) as T);
        } else if (typeof defaultValue === "string") {
          setState(stored as T);
        } else {
          setState(JSON.parse(stored) as T);
        }
      }
    } catch (error) {
      console.warn(`Error reading localStorage key "${key}":`, error);
    } finally {
      setIsInitialized(true);
    }
  }, [key, isInitialized]); // 移除 defaultValue 依赖

  // 保存值到 localStorage（只在初始化后执行）
  useEffect(() => {
    if (!isInitialized) return;

    try {
      const valueToStore =
        typeof state === "object" ? JSON.stringify(state) : String(state);
      window.localStorage.setItem(key, valueToStore);
    } catch (error) {
      console.warn(`Error setting localStorage key "${key}":`, error);
    }
  }, [key, state, isInitialized]);

  return [state, setState];
}
