/*
  Warnings:

  - You are about to drop the column `tiIID` on the `TestResult` table. All the data in the column will be lost.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_TestResult" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "clientTime" DATETIME,
    "receptionTime" DATETIME,
    "returnTime" DATETIME,
    "delay" INTEGER NOT NULL,
    "ip" TEXT NOT NULL,
    "location" TEXT,
    "storeID" TEXT NOT NULL,
    "storeName" TEXT,
    "tiiID" TEXT,
    CONSTRAINT "TestResult_storeID_fkey" FOREIGN KEY ("storeID") REFERENCES "Store" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_TestResult" ("clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime", "storeID", "storeName") SELECT "clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime", "storeID", "storeName" FROM "TestResult";
DROP TABLE "TestResult";
ALTER TABLE "new_TestResult" RENAME TO "TestResult";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
