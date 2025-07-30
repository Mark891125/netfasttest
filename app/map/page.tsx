"use client";
import React, { useEffect, useRef, useState } from "react";
import * as echarts from "echarts";
import chinaMap from "./china.json";
import useLocalStorage from "@/app/hooks/useLocalStorage";

const delayCharts: React.FC = () => {
  const chartRef = useRef<HTMLDivElement>(null);

  const [points, setPoints] = useState<
    { name: string; value: number[]; avg: number | null; offline: boolean }[]
  >([]);
  const [specialList, setSpecialList] = useState<
    { name: string; avg: number | null; offline: boolean }[]
  >([]);
  // 地图中心和缩放状态，使用 useLocalStorage Hook
  const [center, setCenter] = useLocalStorage<[number, number]>("mapCenter", [106.65, 34.76]);
  const [zoom, setZoom] = useLocalStorage<number>("mapZoom", 1.8);

  const DELAY_LIMIT = 300;

  useEffect(() => {
    // 查询最新一天测试结果
    const fetchData = () => {
      const today = new Date();
      const yyyy = today.getFullYear();
      const mm = String(today.getMonth() + 1).padStart(2, "0");
      const dd = String(today.getDate()).padStart(2, "0");
      const dateStr = `${yyyy}-${mm}-${dd}`;
      fetch(`/admin/api/rt-status`)
        .then((res) => res.json())
        .then((data) => {
          // 省市名称到经纬度映射（可补充更多）
          // const geoCoordMap: Record<string, [number, number]> = {
          //   北京市: [116.4, 39.9],
          //   上海市: [121.47, 31.23],
          //   广东省: [113.27, 23.13],
          //   广州市: [113.27, 23.13],
          //   武汉市: [114.31, 30.52],
          //   南京市: [118.78, 32.04],
          //   杭州市: [120.19, 30.26],
          //   河南省: [113.65, 34.76],
          //   成都市: [104.06, 30.67],
          //   深圳市: [114.05, 22.55],
          //   浙江省: [120.15, 30.28],
          //   四川省: [104.06, 30.67],
          //   重庆市: [106.55, 29.56],
          //   天津市: [117.2, 39.13],
          //   // ...可补充其他省市
          // };
          // const mapping = {
          //   "Beijing III": "北京市",
          //   "Premium Node (Beijing 4)": "北京市",
          //   "Hong Kong III": "香港特别行政区",
          //   北京: "北京市",
          //   重庆: "重庆市",
          //   天津: "天津市",
          //   上海: "上海市",
          //   "Shanghai II": "上海市",
          // };
          // 聚合同一省市的延迟为平均值
          const delayMap: Record<string, number[]> = {};

          const pts = data.results
            .filter(
              (r: any) =>
                typeof r.storeLatitude === "number" &&
                typeof r.storeLongitude === "number"
            )
            .map((r: any) => {
              const avgDelay =
                r.testResult.length > 0
                  ? Math.round(
                      r.testResult.reduce(
                        (sum: number, item: any) => sum + (item.delay ?? 0),
                        0
                      ) / r.testResult.length
                    )
                  : NaN;
              return {
                name: r.storeName || r.location || "",
                value: [
                  r.storeLongitude,
                  r.storeLatitude,
                  isNaN(avgDelay) ? 0 : avgDelay,
                  r.testResult.length,
                ],
                avg: avgDelay || 0,
                offline: isNaN(avgDelay),
              };
            });
          setPoints(pts as any);
          // 统计离线和delay>3000的节点
          const special = pts.filter(
            (p: any) =>
              p.offline || (typeof p.avg === "number" && p.avg > DELAY_LIMIT)
          );
          setSpecialList(special);
        });
    };

    fetchData(); // 首次加载
    const timer = setInterval(fetchData, 5000); // 每5秒轮询

    return () => clearInterval(timer); // 组件卸载时清除定时器
  }, []);

  useEffect(() => {
    let chart: echarts.ECharts | null = null;
    function renderChart() {
      if (chartRef.current) {
        echarts.registerMap("china", chinaMap as any);
        if (!chart) {
          chart = echarts.init(chartRef.current);
        }
        chart.setOption({
          title: {
            text: "",
            left: "center",
          },
          tooltip: {
            trigger: "item",
          },

          geo: {
            type: "map",
            map: "china",
            roam: true, // 允许缩放和拖动
            center: center,
            zoom: zoom,
            emphasis: {
              itemStyle: {
                areaColor: "#3399ff", // 高亮时背景色为蓝色
              },
            },
          },
          series: [
            {
              name: "测速点",
              type: "effectScatter",
              coordinateSystem: "geo",
              data: points.filter(
                (p) => !p.offline && p.avg != null && p.avg > DELAY_LIMIT
              ),
              symbolSize: function (val: any) {
                const recordCount = val[3] ?? 0;
                console.log("recordCount", Math.min(50, recordCount * 4));
                // 根据记录数调整大小，最大40，最小
                return Math.max(20, Math.min(40, recordCount * 3));
              },
              encode: {
                tooltip: [2], // 使用延迟作为提示信息
              },
              emphasis: {
                scale: true,
              },
              showEffectOn: "render",
              rippleEffect: {
                period: 4,
                scale: 2.5,
                brushType: "stroke",
              },
              labelLayout: {
                hideOverlap: true,
                moveOverlap: true,
              },
              itemStyle: {
                shadowBlur: 10,
                shadowColor: "red",
                color: "red",
              },
              zlevel: 3,
            },
            {
              name: "测速点",
              type: "effectScatter",
              coordinateSystem: "geo",
              data: points.filter(
                (p) => !p.offline && p.avg != null && p.avg <= DELAY_LIMIT
              ),
              symbolSize: function (val: any) {
                const recordCount = val[3] ?? 0;
                return Math.max(18, Math.min(40, recordCount));
              },
              encode: {
                tooltip: [2], // 使用延迟作为提示信息
              },
              emphasis: {
                scale: true,
              },
              showEffectOn: "render",
              rippleEffect: {
                period: 4,
                scale: 2.5,
                brushType: "stroke",
              },
              labelLayout: {
                hideOverlap: true,
                moveOverlap: true,
              },
              itemStyle: {
                shadowBlur: 10,
                shadowColor: "green",
                color: "green",
              },
              zlevel: 2,
            },
            {
              name: "测速点",
              type: "scatter",
              coordinateSystem: "geo",
              data: points.filter((p) => p.offline),
              itemStyle: { color: "#888" },
              emphasis: {
                scale: true,
              },
              zlevel: 1,
            },
          ],
        });
        // 监听平移缩放事件，保存最新 center/zoom
        if (chart) {
          chart.off("georoam");
          chart.on("georoam", () => {
            const opt = chart!.getOption();
            const geoOpt = (opt.geo as any)[0] || {};
            const newCenter = geoOpt.center as [number, number];
            const newZoom = geoOpt.zoom as number;
            setCenter(newCenter);
            setZoom(newZoom);
            // localStorage 操作已由 useLocalStorage Hook 自动处理
          });
        }
      }
    }
    renderChart();
    function handleResize() {
      if (chart) {
        chart.resize();
      }
    }
    window.addEventListener("resize", handleResize);
    return () => {
      window.removeEventListener("resize", handleResize);
      if (chart) {
        chart.dispose();
      }
    };
  }, [points]);

  return (
    <div style={{ display: "flex", width: "100%", height: "100vh" }}>
      <div ref={chartRef} style={{ flex: 1, height: "100vh" }} />
      {specialList.length >= 0 ? (
        <div
          style={{
            width: 340,
            height: "100vh",
            overflowY: "auto",
            background: "#f7f8fa",
            borderLeft: "1px solid #e3e3e3",
            padding: 20,
            boxSizing: "border-box",
          }}
        >
          <h3
            style={{
              marginTop: 0,
              marginBottom: 18,
              fontWeight: 600,
              fontSize: 18,
              color: "#333",
            }}
          >
            异常节点 ({specialList.length} / {points.length})
          </h3>
          <ul style={{ padding: 0, margin: 0, listStyle: "none" }}>
            {specialList.map((item, idx) => (
              <li
                key={idx}
                style={{
                  marginBottom: 18,
                  padding: "12px 10px",
                  background: item.offline ? "#f0f0f0" : "#fff",
                  borderRadius: 8,
                  boxShadow: item.offline
                    ? "none"
                    : "0 1px 4px rgba(217,78,93,0.08)",
                  border: item.offline
                    ? "1px solid #e3e3e3"
                    : "1px solid #ffe3e3",
                  color: item.offline ? "#888" : "#d94e5d",
                  display: "flex",
                  alignItems: "center",
                  transition: "box-shadow 0.2s",
                  cursor: "pointer",
                }}
                onMouseEnter={(e) => {
                  (e.currentTarget as HTMLLIElement).style.boxShadow =
                    item.offline ? "none" : "0 2px 8px rgba(217,78,93,0.18)";
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLLIElement).style.boxShadow =
                    item.offline ? "none" : "0 1px 4px rgba(217,78,93,0.08)";
                }}
              >
                <div style={{ flex: 1 }}>
                  <div
                    style={{
                      fontWeight: 500,
                      fontSize: 15,
                      marginBottom: 2,
                      color: item.offline ? "#888" : "#d94e5d",
                    }}
                  >
                    {item.name}
                  </div>
                  <div
                    style={{
                      fontSize: 14,
                      color: item.offline ? "#aaa" : "#d94e5d",
                      fontWeight: 400,
                    }}
                  >
                    {item.offline ? (
                      "离线"
                    ) : (
                      <span>
                        延迟:{" "}
                        <span style={{ fontWeight: 600 }}>{item.avg}ms</span>
                      </span>
                    )}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  );
};

export default delayCharts;
