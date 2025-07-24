import { PrismaClient } from "@prisma/client";
import { v4 as uuidv4 } from "uuid";
const prisma = new PrismaClient();

// export async function main() {
//   // 插入测试数据
//   await prisma.testResult.createMany({
//     data: [
//       // 本地网络
//       {
//         id: "test-local-1",
//         clientTime: new Date(Date.now() - 10000),
//         receptionTime: new Date(Date.now() - 9000),
//         returnTime: new Date(Date.now() - 8000),
//         delay: 100,
//         ip: "127.0.0.1",
//         location: "本地网络",
//         storeID: "store-local",
//       },
//       {
//         id: "test-local-2",
//         clientTime: new Date(Date.now() - 11000),
//         receptionTime: new Date(Date.now() - 10000),
//         returnTime: new Date(Date.now() - 9000),
//         delay: 100,
//         ip: "::1",
//         location: "本地网络",
//         storeID: "store-local",
//       },
//       {
//         id: "test-local-3",
//         clientTime: new Date(Date.now() - 12000),
//         receptionTime: new Date(Date.now() - 11000),
//         returnTime: new Date(Date.now() - 10000),
//         delay: 100,
//         ip: "192.168.1.100",
//         location: "本地网络",
//         storeID: "store-local",
//       },
//       {
//         id: "test-local-4",
//         clientTime: new Date(Date.now() - 13000),
//         receptionTime: new Date(Date.now() - 12000),
//         returnTime: new Date(Date.now() - 11000),
//         delay: 100,
//         ip: "10.0.0.1",
//         location: "本地网络",
//         storeID: "store-local",
//       },
//       {
//         id: "test-local-5",
//         clientTime: new Date(Date.now() - 14000),
//         receptionTime: new Date(Date.now() - 13000),
//         returnTime: new Date(Date.now() - 12000),
//         delay: 100,
//         ip: "172.16.0.1",
//         location: "本地网络",
//         storeID: "store-local",
//       },
//       // Premium Node (Beijing 4)
//       {
//         id: "test-bj4-1",
//         clientTime: new Date(Date.now() - 15000),
//         receptionTime: new Date(Date.now() - 14000),
//         returnTime: new Date(Date.now() - 13000),
//         delay: 100,
//         ip: "120.136.21.88",
//         location: "Premium Node (Beijing 4)",
//         storeID: "store-bj4",
//       },
//       {
//         id: "test-bj4-2",
//         clientTime: new Date(Date.now() - 16000),
//         receptionTime: new Date(Date.now() - 15000),
//         returnTime: new Date(Date.now() - 14000),
//         delay: 100,
//         ip: "202.57.204.99",
//         location: "Premium Node (Beijing 4)",
//         storeID: "store-bj4",
//       },
//       {
//         id: "test-bj4-3",
//         clientTime: new Date(Date.now() - 17000),
//         receptionTime: new Date(Date.now() - 16000),
//         returnTime: new Date(Date.now() - 15000),
//         delay: 100,
//         ip: "202.57.205.100",
//         location: "Premium Node (Beijing 4)",
//         storeID: "store-bj4",
//       },
//       // Shanghai II
//       {
//         id: "test-sh2-1",
//         clientTime: new Date(Date.now() - 18000),
//         receptionTime: new Date(Date.now() - 17000),
//         returnTime: new Date(Date.now() - 16000),
//         delay: 100,
//         ip: "140.210.152.1",
//         location: "Shanghai II",
//         storeID: "store-sh2",
//       },
//       {
//         id: "test-sh2-2",
//         clientTime: new Date(Date.now() - 19000),
//         receptionTime: new Date(Date.now() - 18000),
//         returnTime: new Date(Date.now() - 17000),
//         delay: 100,
//         ip: "140.210.153.2",
//         location: "Shanghai II",
//         storeID: "store-sh2",
//       },
//       // Beijing III
//       {
//         id: "test-bj3-1",
//         clientTime: new Date(Date.now() - 20000),
//         receptionTime: new Date(Date.now() - 19000),
//         returnTime: new Date(Date.now() - 18000),
//         delay: 100,
//         ip: "220.243.154.3",
//         location: "Beijing III",
//         storeID: "store-bj3",
//       },
//       {
//         id: "test-bj3-2",
//         clientTime: new Date(Date.now() - 21000),
//         receptionTime: new Date(Date.now() - 20000),
//         returnTime: new Date(Date.now() - 19000),
//         delay: 100,
//         ip: "220.243.155.4",
//         location: "Beijing III",
//         storeID: "store-bj3",
//       },
//       // Hong Kong III
//       {
//         id: "test-hk3-1",
//         clientTime: new Date(Date.now() - 22000),
//         receptionTime: new Date(Date.now() - 21000),
//         returnTime: new Date(Date.now() - 20000),
//         delay: 100,
//         ip: "202.57.205.5",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-2",
//         clientTime: new Date(Date.now() - 23000),
//         receptionTime: new Date(Date.now() - 22000),
//         returnTime: new Date(Date.now() - 21000),
//         delay: 100,
//         ip: "202.57.206.6",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-3",
//         clientTime: new Date(Date.now() - 24000),
//         receptionTime: new Date(Date.now() - 23000),
//         returnTime: new Date(Date.now() - 22000),
//         delay: 100,
//         ip: "165.225.234.7",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-4",
//         clientTime: new Date(Date.now() - 25000),
//         receptionTime: new Date(Date.now() - 24000),
//         returnTime: new Date(Date.now() - 23000),
//         delay: 100,
//         ip: "165.225.235.8",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-5",
//         clientTime: new Date(Date.now() - 26000),
//         receptionTime: new Date(Date.now() - 25000),
//         returnTime: new Date(Date.now() - 24000),
//         delay: 100,
//         ip: "136.226.228.9",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-6",
//         clientTime: new Date(Date.now() - 27000),
//         receptionTime: new Date(Date.now() - 26000),
//         returnTime: new Date(Date.now() - 25000),
//         delay: 100,
//         ip: "136.226.229.10",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-7",
//         clientTime: new Date(Date.now() - 28000),
//         receptionTime: new Date(Date.now() - 27000),
//         returnTime: new Date(Date.now() - 26000),
//         delay: 100,
//         ip: "167.103.0.11",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//       {
//         id: "test-hk3-8",
//         clientTime: new Date(Date.now() - 29000),
//         receptionTime: new Date(Date.now() - 28000),
//         returnTime: new Date(Date.now() - 27000),
//         delay: 100,
//         ip: "167.103.1.12",
//         location: "Hong Kong III",
//         storeID: "store-hk3",
//       },
//     ],
//   });
// }
function randomDateInLastWeek() {
  const now = Date.now();
  const week = 7 * 24 * 60 * 60 * 1000;
  return new Date(now - Math.floor(Math.random() * week));
}

function randomIP() {
  return `${Math.floor(Math.random() * 256)}.${Math.floor(
    Math.random() * 256
  )}.${Math.floor(Math.random() * 256)}.${Math.floor(Math.random() * 256)}`;
}

function randomStoreID() {
  return `CN${Math.floor(Math.random() * 1000)}`;
}

function randomLocation() {
  const locations = [
    "北京市",
    "上海市",
    "广州",
    "深圳",
    "成都",
    "杭州",
    "武汉",
    "西安",
    "南京",
    "重庆",
  ];
  return locations[Math.floor(Math.random() * locations.length)];
}

export async function main() {
  const BATCH_SIZE = 1000;
  const TOTAL = 100_000;
  for (let i = 0; i < TOTAL; i += BATCH_SIZE) {
    const batch = Array.from(
      { length: Math.min(BATCH_SIZE, TOTAL - i) },
      (_, idx) => {
        const clientTime = randomDateInLastWeek();
        return {
          id: uuidv4(),
          clientTime,
          receptionTime: new Date(
            clientTime.getTime() + Math.floor(Math.random() * 1000)
          ),
          returnTime: new Date(
            clientTime.getTime() + Math.floor(Math.random() * 2000)
          ),
          delay: Math.floor(Math.random() * 5000),
          ip: randomIP(),
          location: randomLocation(),
          storeID: randomStoreID(),
        };
      }
    );
    await prisma.testResult.createMany({ data: batch });
    console.log(`Inserted ${i + batch.length} / ${TOTAL}`);
  }
}
main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
