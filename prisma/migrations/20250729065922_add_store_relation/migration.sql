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
    CONSTRAINT "TestResult_storeID_fkey" FOREIGN KEY ("storeID") REFERENCES "Store" ("code") ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO "new_TestResult" ("clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime", "storeID", "storeName", "tiiID") SELECT "clientTime", "delay", "id", "ip", "location", "receptionTime", "returnTime", "storeID", "storeName", "tiiID" FROM "TestResult";
DROP TABLE "TestResult";
ALTER TABLE "new_TestResult" RENAME TO "TestResult";
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
