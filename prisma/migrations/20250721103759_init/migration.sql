/*
  Warnings:

  - The primary key for the `TestResult` table will be changed. If it partially fails, the table could be left without primary key constraint.

*/
-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_TestResult" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "clientTime" DATETIME NOT NULL,
    "receptionTime" DATETIME NOT NULL,
    "returnTime" DATETIME NOT NULL,
    "delay" INTEGER NOT NULL,
    "ip" TEXT NOT NULL,
    "location" TEXT
);
INSERT INTO "new_TestResult" ("clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime") SELECT "clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime" FROM "TestResult";
DROP TABLE "TestResult";
ALTER TABLE "new_TestResult" RENAME TO "TestResult";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
