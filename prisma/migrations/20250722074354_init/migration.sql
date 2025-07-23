/*
  Warnings:

  - Made the column `storeID` on table `TestResult` required. This step will fail if there are existing NULL values in that column.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_TestResult" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "storeID" TEXT NOT NULL,
    "clientTime" DATETIME,
    "receptionTime" DATETIME,
    "returnTime" DATETIME,
    "delay" INTEGER NOT NULL,
    "ip" TEXT NOT NULL,
    "location" TEXT
);
INSERT INTO "new_TestResult" ("clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime", "storeID") SELECT "clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime", "storeID" FROM "TestResult";
DROP TABLE "TestResult";
ALTER TABLE "new_TestResult" RENAME TO "TestResult";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
