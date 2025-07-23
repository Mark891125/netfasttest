"use client";

import { useState, useEffect } from "react";
import styles from "./page.module.css";
import NetworkStatus from "./components/NetworkStatus";

interface TestResult {
  id: string;
  timestamp: string;
  delay: number;
  ip: string;
  location: string;
}

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);
  const [currentTest, setCurrentTest] = useState<TestResult | null>(null);
  const [testHistory, setTestHistory] = useState<TestResult[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [rtt, setRTT] = useState<number>(0);
  const [timeDiff, setTimeDiff] = useState<number>(0);

  // 从sessionStorage加载历史记录
  useEffect(() => {
    const saved = sessionStorage.getItem("speedTestHistory");
    if (saved) {
      setTestHistory(JSON.parse(saved));
    }
    // 页面加载时同步服务器时间
    syncServerTime();
  }, []);

  /**
   * 使用NTP算法原理计算客户端与服务端的时钟差
   * 公式: 时钟差 = ((T2 - T1) + (T3 - T4)) / 2
   * T1: 客户端发送时间
   * T2: 服务端接收时间
   * T3: 服务端发送时间
   * T4: 客户端接收时间
   */
  function calculateClockOffset(
    clientSendTime: number,
    serverReceiveTime: number,
    serverSendTime: number,
    clientReceiveTime: number
  ): number {
    return (
      (serverReceiveTime -
        clientSendTime +
        (serverSendTime - clientReceiveTime)) /
      2
    );
  }

  // 同步服务器时间
  const syncServerTime = async () => {
    try {
      const clientSendTime = Date.now();
      const response = await fetch("/api/speed-test?_t=" + clientSendTime);
      const clientReceiveTime = Date.now();

      if (response.ok) {
        // 计算往返时间 (RTT)
        const rtt = clientReceiveTime - clientSendTime;

        setRTT(rtt);
      }
    } catch (error) {
      console.error("服务器时间同步失败:", error);
    }
  };

  // 保存历史记录到sessionStorage
  const saveToHistory = (result: TestResult) => {
    const newHistory = [result, ...testHistory].slice(0, 20); // 最多保存20条记录
    setTestHistory(newHistory);
    sessionStorage.setItem("speedTestHistory", JSON.stringify(newHistory));
  };
  // 提交测试结果
  const submitTestResult = async (id: string, delay: number) => {
    try {
      const response = await fetch("/api/update-result", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ id, delay }),
      });

      if (response.ok) {
        const result = await response.json();
        console.log("测试结果上传成功:", result);
      } else {
        console.error("测试结果上传失败");
      }
    } catch (error) {
      console.error("提交测试结果失败:", error);
    }
  };

  // 执行网络网速测试
  const runLatencyTest = async () => {
    setIsLoading(true);
    try {
      const clientSendTime = Date.now();
      const response = await fetch("/api/speed-test", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          timestamp: Date.now(), // 发送调整后的时间戳
          storeID: "default", // 假设有一个默认的storeID
        }),
      });
      const clientReceiveTime = Date.now();

      if (response.ok) {
        const result = await response.json();

        // 显示本地化时间
        const timezone =
          Intl.DateTimeFormat().resolvedOptions().timeZone || "Asia/Shanghai";
        const timestamp = new Date().toLocaleDateString("zh-CN", {
          timeZone: timezone,
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        });
        result.data.timestamp = timestamp;

        const { receptionTime, returnTime } = result.data;

        // const delay = clientReceiveTime - clientSendTime;

        const serverProcessingTime = returnTime - receptionTime;
        const totalTime = clientReceiveTime - clientSendTime;
        const delay = totalTime - serverProcessingTime;

        const timeDiff = calculateClockOffset(
          clientSendTime,
          receptionTime,
          returnTime,
          clientReceiveTime
        );
        setTimeDiff(timeDiff);

        if (result.data.location === "") {
          const location = fetchIPLocation(result.data.ip);
          result.data.location = location;
        }
        // 直接使用服务器返回的网络延迟时间
        setCurrentTest({
          ...result.data,
          delay,
        });

        saveToHistory({
          ...result.data,
          delay,
        });
        // 提交数据库
        submitTestResult(result.data.id, delay);
      }

      // 测试完成后重新同步时间，为下次测试做准备
      await syncServerTime();
    } catch (error) {
      console.error("网速测试失败:", error);
    } finally {
      setIsLoading(false);
    }
  };

  async function fetchIPLocation(ip: string): Promise<string> {
    // const clientIP = "220.243.155.79";
    const clientIP = ip;
    // 只对非本地IP进行地理位置查询
    if (
      clientIP == "127.0.0.1" ||
      clientIP.startsWith("::1") ||
      clientIP.startsWith("192.168.") ||
      clientIP.startsWith("10.") ||
      clientIP.startsWith("172.")
    ) {
      return Promise.resolve("本地网络");
    } else {
      console.log(`查询IP地址: ${clientIP}`);

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3000); // 3秒超时
      const ipResponse = await fetch(`https://ipapi.co/${clientIP}/json/`, {
        signal: controller.signal,
      });
      clearTimeout(timeoutId); // 清除超时计时器

      if (ipResponse.ok) {
        const ipData = await ipResponse.json();
        return ipData.location || "未知位置";
      } else {
        return "未知位置";
      }
    }
  }
  // 清除历史记录
  const clearHistory = () => {
    setTestHistory([]);
    sessionStorage.removeItem("speedTestHistory");
  };

  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <div className={styles.container}>
          <div className={styles.header}>
            <h1 className={styles.title}>网络测试</h1>
            <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
              <NetworkStatus
                className="nt-status"
                rtt={rtt}
                timeDiff={timeDiff}
              />
            </div>
          </div>

          <div className={styles.testSection}>
            <div className={styles.buttonGroup}>
              <button
                onClick={runLatencyTest}
                disabled={isLoading}
                className={styles.testButton}
              >
                {isLoading ? "测试中..." : "网速测试"}
              </button>
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
                    <div>
                      <label>网络延迟:</label>
                      <div style={{ fontSize: "12px", color: "#7e7e7e" }}>
                        延迟小于3000ms 为正常
                      </div>
                    </div>

                    <span>{currentTest.delay}ms</span>
                  </div>
                  <div className={styles.resultItem}>
                    <label>位置:</label>
                    <span>{currentTest.location}</span>
                  </div>
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
                {showHistory ? "隐藏历史记录" : "显示历史记录"} (
                {testHistory.length})
              </button>
              {testHistory.length > 0 && (
                <button onClick={clearHistory} className={styles.clearButton}>
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
                        <span>延迟: {test.delay}ms</span>
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
