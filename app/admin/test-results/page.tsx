"use client";
import React, { useEffect, useState } from "react";
import "../admin-globals.scss";
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

const PAGE_SIZE = 20;

export default function TestResultsPage() {
  const today = new Date();
  const yyyy = today.getFullYear();
  const mm = String(today.getMonth() + 1).padStart(2, "0");
  const dd = String(today.getDate()).padStart(2, "0");
  const defaultDate = `${yyyy}-${mm}-${dd}`;

  const [results, setResults] = useState<TestResult[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [keyword, setKeyword] = useState("");
  const [date, setDate] = useState(() => {
    if (typeof window !== "undefined") {
      return localStorage.getItem("testResultsDate") || defaultDate;
    }
    return defaultDate;
  });

  const fetchData = (pageNum = 1) => {
    setLoading(true);
    setError("");
    const params = new URLSearchParams();
    if (keyword) params.append("keyword", keyword);
    if (date) params.append("date", date);
    params.append("page", String(pageNum));
    params.append("pageSize", String(PAGE_SIZE));
    fetch(`/admin/api/test-results?${params.toString()}`)
      .then((res) => {
        if (!res.ok) throw new Error("加载失败");
        return res.json();
      })
      .then((data) => {
        setResults(data.results);
        setTotal(data.total);
        setPage(data.page);
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchData(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (typeof window !== "undefined") {
      localStorage.setItem("testResultsDate", date);
    }
    fetchData(1);
  };

  const totalPages = Math.ceil(total / PAGE_SIZE);

  // 分页按钮事件
  const handlePageChange = (newPage: number) => {
    fetchData(newPage);
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
            if (typeof window !== "undefined") {
              localStorage.setItem("testResultsDate", e.target.value);
            }
          }}
        />
        <button type="submit">搜索</button>
      </form>
      {loading && <p className={styles.loading}>加载中...</p>}
      {error && <p className={styles.error}>{error}</p>}
      {!loading && !error && (
        <>
          <div className={styles["table-wrapper"]}>
            <table>
              <thead>
                <tr>
                  <th style={{ width: 60 }}>#</th>
                  <th style={{ width: 120 }}>StoreID</th>
                  <th style={{ width: 200 }}>TestTime</th>
                  <th style={{ width: 120 }}>Delay</th>
                  <th style={{ width: 160 }}>IP</th>
                  <th>Location</th>
                </tr>
              </thead>
              <tbody>
                {results.map((r, idx) => (
                  <tr key={r.id}>
                    <td data-label="#">{(page - 1) * PAGE_SIZE + idx + 1}</td>
                    <td data-label="StoreID">{r.storeID}</td>
                    <td data-label="TestTime">
                      {r.clientTime
                        ? new Date(r.clientTime).toLocaleString()
                        : ""}
                    </td>
                    <td
                      data-label="Delay"
                      className={styles.delay}
                      style={{ color: r.delay > 3000 ? "red" : "black" }}
                    >
                      {r.delay}
                    </td>
                    <td data-label="IP">{r.ip}</td>
                    <td data-label="Location">{r.location || ""}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {/* 分页控件 - 扁平化美化 */}
            {totalPages > 1 && (
              <div className={styles.pagination}>
                <button
                  className={styles.pageBtn}
                  onClick={() => handlePageChange(page - 1)}
                  disabled={page === 1}
                >
                  上一页
                </button>
                <span className={styles.pageInfo}>
                  第 {page} / {totalPages} 页
                </span>
                <button
                  className={styles.pageBtn}
                  onClick={() => handlePageChange(page + 1)}
                  disabled={page === totalPages}
                >
                  下一页
                </button>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
