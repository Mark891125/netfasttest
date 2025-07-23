"use client";
import React, { useEffect, useState } from "react";
import styles from "./page.module.scss";

interface TestResult {
  id: string;
  storeID: string;
  clientTime?: string;
  receptionTime?: string;
  returnTime?: string;
  delay: number;
  ip: string;
  location?: string;
}


export default function TestResultsPage() {
  const today = new Date();
  const yyyy = today.getFullYear();
  const mm = String(today.getMonth() + 1).padStart(2, "0");
  const dd = String(today.getDate()).padStart(2, "0");
  const defaultDate = `${yyyy}-${mm}-${dd}`;

  const [results, setResults] = useState<TestResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [keyword, setKeyword] = useState("");
  // 优先从 localStorage 读取缓存日期
  const [date, setDate] = useState(() => {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('testResultsDate') || defaultDate;
    }
    return defaultDate;
  });

  const fetchData = () => {
    setLoading(true);
    setError("");
    const params = new URLSearchParams();
    if (keyword) params.append("keyword", keyword);
    if (date) params.append("date", date);
    fetch(`/admin/api/test-results?${params.toString()}`)
      .then((res) => {
        if (!res.ok) throw new Error("加载失败");
        return res.json();
      })
      .then(setResults)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    // 搜索时缓存日期
    if (typeof window !== 'undefined') {
      localStorage.setItem('testResultsDate', date);
    }
    fetchData();
  };

  return (
    <div className={styles["test-results-page"]}>
      <h1>测试结果列表</h1>
      <form className={styles["search-form"]} onSubmit={handleSearch}>
        <input
          type="text"
          placeholder="店铺ID/IP/Location"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
        />
        <input
          type="date"
          value={date}
          onChange={(e) => {
            setDate(e.target.value);
            if (typeof window !== 'undefined') {
              localStorage.setItem('testResultsDate', e.target.value);
            }
          }}
        />
        <button type="submit">搜索</button>
      </form>
      {loading && <p className={styles.loading}>加载中...</p>}
      {error && <p className={styles.error}>{error}</p>}
      {!loading && !error && (
        <div className={styles["table-wrapper"]}>
          <table>
            <thead>
              <tr>
                {/* <th>ID</th> */}
                <th style={{ width: 120 }}>StoreID</th>
                <th style={{ width: 200 }}>TestTime</th>
                <th style={{ width: 120 }}>Delay</th>
                <th style={{ width: 220 }}>IP</th>
                <th>Location</th>
              </tr>
            </thead>
            <tbody>
              {results.map((r) => (
                <tr key={r.id}>
                  <td>{r.storeID}</td>
                  <td>
                    {r.clientTime
                      ? new Date(r.clientTime).toLocaleString()
                      : ""}
                  </td>
                  <td
                    className={styles.delay}
                    style={{ color: r.delay > 3000 ? "red" : "black" }}
                  >
                    {r.delay}
                  </td>
                  <td>{r.ip}</td>
                  <td>{r.location || ""}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
