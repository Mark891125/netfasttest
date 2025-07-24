"use client";
import React, { useEffect, useRef, useState } from "react";
import * as echarts from "echarts";
import chinaMap from "./china.json";

const delayCharts: React.FC = () => {
  const chartRef = useRef<HTMLDivElement>(null);

  const [points, setPoints] = useState<{ name: string; value: number }[]>([]);

  useEffect(() => {
    // 查询最新一天测试结果
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, "0");
    const dd = String(today.getDate()).padStart(2, "0");
    const dateStr = `${yyyy}-${mm}-${dd}`;
    fetch(`/admin/api/test-results?page=1&pageSize=200`)
      .then((res) => res.json())
      .then((data) => {
        //
        // 省市名称到经纬度映射（可补充更多）
        const geoCoordMap: Record<string, [number, number]> = {
          北京市: [116.4, 39.9],
          上海市: [121.47, 31.23],
          广东省: [113.27, 23.13],
          广州市: [113.27, 23.13],
          武汉市: [114.31, 30.52],
          南京市: [118.78, 32.04],
          杭州市: [120.19, 30.26],
          河南省: [113.65, 34.76],
          成都市: [104.06, 30.67],
          深圳市: [114.05, 22.55],
          浙江省: [120.15, 30.28],
          四川省: [104.06, 30.67],
          重庆市: [106.55, 29.56],
          天津市: [117.2, 39.13],
          // ...可补充其他省市
        };
        const mapping = {
          "Beijing III": "北京市",
          "Premium Node (Beijing 4)": "北京市",
          "Hong Kong III": "香港特别行政区",
          北京: "北京市",
          重庆: "重庆市",
          天津: "天津市",
          上海: "上海市",
          "Shanghai II": "上海市",
        };
        // 聚合同一省市的延迟为平均值
        const delayMap: Record<string, number[]> = {};
        (data.results || [])
          .filter((r: any) => r.location && typeof r.delay === "number")
          .forEach((r: any) => {
            let name = r.location;
            if (name in mapping) name = mapping[name as keyof typeof mapping];
            else name = name + "省";
            if (!delayMap[name]) delayMap[name] = [];
            delayMap[name].push(r.delay);
          });
        const pts = Object.entries(delayMap)
          .map(([name, delays]) => {
            const coord = geoCoordMap[name];
            if (coord) {
              const avg = Math.round(
                delays.reduce((a, b) => a + b, 0) / delays.length
              );
              return { name, value: [...coord, avg], avg };
            }
            return null;
          })
          .filter(Boolean);
        setPoints(pts as any);
      });
  }, []);

  useEffect(() => {
    let chart: echarts.ECharts | null = null;
    function renderChart() {
      if (chartRef.current) {
        if (!(echarts as any).maps?.china) {
          echarts.registerMap("china", chinaMap as any);
        }
        if (!chart) {
          chart = echarts.init(chartRef.current);
        }
        chart.setOption({
          title: {
            text: "最新一日延迟分布",
            left: "center",
          },
          tooltip: {
            trigger: "item",
          },
          visualMap: {
            min: 0,
            max: 100,
            left: "left",
            top: "bottom",
            text: ["高延迟", "低延迟"],
            inRange: {
              color: ["#50a3ba", "#eac736", "#d94e5d"],
            },
            show: true,
          },
          geo: {
            type: "map",
            map: "china",
            roam: true, // 允许缩放和拖动
            center: [113.65, 34.76], // 河南经纬度
            zoom: 4,
            emphasis: {
              label: {
                // show: false
              },
              itemStyle: {
                areaColor: "#4474ec", // 高亮时区域颜色
              },
            },
          },
          series: [
            {
              name: "延迟点",
              type: "effectScatter",
              coordinateSystem: "geo",
              data: points,
              symbolSize: function (value: any) {
                return value[2] / 500;
              },
              encode: {
                value: 2,
              },
              showEffectOn: "render",
              rippleEffect: {
                brushType: "stroke",
                color: "red",
              },
              emphasis: {
                scale: false,
              },
              itemStyle: {
                shadowBlur: 10,
                shadowColor: "rgba(0, 0, 0, 1)",
                color: "red",
              },
              zlevel: 1,
              label: {
                show: true,
                position: "bottom",
                formatter: function (params: any) {
                  return params.data.avg + "ms";
                },
                color: "#d94e5d",
                fontSize: 12,
              },
            },
          ],
        });
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

  return <div ref={chartRef} style={{ width: "100%", height: "100vh" }} />;
};

export default delayCharts;
