-- CreateTable
CREATE TABLE "TestResult" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "clientTime" DATETIME NOT NULL,
    "receptionTime" DATETIME NOT NULL,
    "returnTime" DATETIME NOT NULL,
    "delay" INTEGER NOT NULL,
    "ip" TEXT NOT NULL,
    "location" TEXT
);
