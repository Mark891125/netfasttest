'use client'

import { useState, useEffect } from 'react';
import styles from "./page.module.css";
import NetworkStatus from './components/NetworkStatus';

interface TestResult {
  id: string;
  timestamp: string;
  ip: string;
  location: string;
  country: string;
  city: string;
  responseTime: number;
  downloadSpeed?: number;
  uploadSpeed?: number;
  requestSize: number;
  userAgent: string;
}

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);
  const [currentTest, setCurrentTest] = useState<TestResult | null>(null);
  const [testHistory, setTestHistory] = useState<TestResult[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [timeDiff, setTimeDiff] = useState<number>(0); // 服务器时间与本地时间的差值

  // 从sessionStorage加载历史记录
  useEffect(() => {
    const saved = sessionStorage.getItem('speedTestHistory');
    if (saved) {
      setTestHistory(JSON.parse(saved));
    }
    
    // 页面加载时同步服务器时间
    syncServerTime();
  }, []);

  // 同步服务器时间
  const syncServerTime = async () => {
    try {
      const clientRequestTime = Date.now();
      const response = await fetch('/api/speed-test?action=get-server-time');
      const clientReceiveTime = Date.now();
      
      if (response.ok) {
        const result = await response.json();
        const serverTime = result.data.serverTime;
        
        // 计算网络延迟的一半作为估算的单程延迟
        const networkDelay = (clientReceiveTime - clientRequestTime) / 2;
        
        // 估算服务器当前时间（考虑网络延迟）
        const estimatedServerTime = serverTime + networkDelay;
        
        // 计算时间差（服务器时间 - 本地时间）
        const diff = estimatedServerTime - clientReceiveTime;
        setTimeDiff(diff);
        
        console.log(`时间同步完成: 服务器时间差值 ${diff.toFixed(2)}ms, 网络延迟: ${networkDelay.toFixed(2)}ms`);
      }
    } catch (error) {
      console.error('服务器时间同步失败:', error);
      setTimeDiff(0); // 同步失败时使用本地时间
    }
  };

  // 保存历史记录到sessionStorage
  const saveToHistory = (result: TestResult) => {
    const newHistory = [result, ...testHistory].slice(0, 20); // 最多保存20条记录
    setTestHistory(newHistory);
    sessionStorage.setItem('speedTestHistory', JSON.stringify(newHistory));
  };

  // 执行网络延迟测试
  const runLatencyTest = async () => {
    setIsLoading(true);
    try {
      const clientLocalTime = Date.now();
      // 使用同步后的时间差计算服务器时间
      const serverAdjustedTime = clientLocalTime + timeDiff;
      
      const response = await fetch('/api/speed-test', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ 
          test: 'latency',
          timestamp: serverAdjustedTime // 发送调整后的时间戳
        })
      });
      
      if (response.ok) {
        const result = await response.json();
        // 直接使用服务器返回的网络延迟时间
        setCurrentTest(result.data);
        saveToHistory(result.data);
        
        console.log(`网络延迟测试完成: ${result.data.responseTime}ms (基于服务器时间同步)`);
      }
    } catch (error) {
      console.error('延迟测试失败:', error);
    } finally {
      setIsLoading(false);
    }
  };

  // 清除历史记录
  const clearHistory = () => {
    setTestHistory([]);
    sessionStorage.removeItem('speedTestHistory');
  };

  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <div className={styles.container}>
          <div className={styles.header}>
            <h1 className={styles.title}>网络测试</h1>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{ fontSize: '12px', color: '#666' }}>
                时间同步: {timeDiff !== 0 ? `${timeDiff > 0 ? '+' : ''}${timeDiff.toFixed(1)}ms` : '本地时间'}
              </div>
              <NetworkStatus className={styles.networkStatus} />
            </div>
          </div>
          
          <div className={styles.testSection}>
            <div className={styles.buttonGroup}>
              <button 
                onClick={runLatencyTest} 
                disabled={isLoading}
                className={styles.testButton}
              >
                {isLoading ? '测试中...' : '延迟测试'}
              </button>
              {/* <button 
                onClick={runDownloadTest} 
                disabled={isLoading}
                className={styles.testButton}
              >
                {isLoading ? '测试中...' : '下载测试'}
              </button> */}
            </div>
            
            {currentTest && (
              <div className={styles.result}>
                <h3>测试结果</h3>
                <div className={styles.resultGrid}>
                  <div className={styles.resultItem}>
                    <label>时间:</label>
                    <span>{currentTest.timestamp}</span>
                  </div>
                  <div className={styles.resultItem}>
                    <label>IP地址:</label>
                    <span>{currentTest.ip}</span>
                  </div>
                  <div className={styles.resultItem}>
                    <label>位置:</label>
                    <span>{currentTest.location}</span>
                  </div>
                  <div className={styles.resultItem}>
                    <label>网络延迟:</label>
                    <span>{currentTest.responseTime}ms</span>
                  </div>
                  {currentTest.downloadSpeed && (
                    <div className={styles.resultItem}>
                      <label>下载速度:</label>
                      <span>{currentTest.downloadSpeed} Mbps</span>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
          
          <div className={styles.historySection}>
            <div className={styles.historyHeader}>
              <button 
                onClick={() => setShowHistory(!showHistory)}
                className={styles.historyToggle}
              >
                {showHistory ? '隐藏历史记录' : '显示历史记录'} ({testHistory.length})
              </button>
              {testHistory.length > 0 && (
                <button 
                  onClick={clearHistory}
                  className={styles.clearButton}
                >
                  清除记录
                </button>
              )}
            </div>
            
            {showHistory && (
              <div className={styles.historyList}>
                {testHistory.length === 0 ? (
                  <p className={styles.emptyHistory}>暂无测试记录</p>
                ) : (
                  testHistory.map((test) => (
                    <div key={test.id} className={styles.historyItem}>
                      <div className={styles.historyTime}>{test.timestamp}</div>
                      <div className={styles.historyDetails}>
                        <span>IP: {test.ip}</span>
                        <span>位置: {test.location}</span>
                        <span>延迟: {test.responseTime}ms</span>
                        {test.downloadSpeed && (
                          <span>下载: {test.downloadSpeed} Mbps</span>
                        )}
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
