import React, { useState } from "react";
import styles from "./SettingModal.module.scss";

interface Store {
  id: string;
  name: string;
}

interface SettingModalProps {
  tiiID: string;
  setTiiID: (id: string) => void;
  storeID: string;
  setStoreID: (id: string) => void;
  storeList: Store[];
  autoTest: boolean;
  setAutoTest: (v: boolean) => void;
  autoTestTimer: number;
}
const SettingModal: React.FC<SettingModalProps> = ({
  tiiID,
  setTiiID,
  storeID,
  setStoreID,
  storeList,
  autoTest,
  setAutoTest,
  autoTestTimer,
}) => {
  const [showSetting, setShowSetting] = useState(false);
  if (showSetting) {
    return (
      <div className={styles.modalWrapper}>
        <h3 className={styles.title}>设置</h3>
        <div className={styles.formItem}>
          <label className={styles.label}>TiIID</label>
          <input
            type="text"
            value={tiiID}
            onChange={(e) => setTiiID(e.target.value)}
            className={styles.input}
            placeholder="请输入TiIID"
          />
        </div>
        <div className={styles.formItem}>
          <label className={styles.label}>测试店铺</label>
          <select
            value={storeID}
            onChange={(e) => setStoreID(e.target.value)}
            className={styles.select}
          >
            {storeList.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </div>
        <div className={styles.formItem}>
          <label className={styles.checkboxLabel}>
            <input
              type="checkbox"
              checked={autoTest}
              onChange={(e) => setAutoTest(e.target.checked)}
              className={styles.checkbox}
            />
            持续测试
            {autoTest && (
              <span className={styles.timer}>
                下次测试倒计时：{autoTestTimer}s
              </span>
            )}
          </label>
          <div className={styles.desc}>
            开启后每5分钟自动测试一次，连续测试10次
          </div>
        </div>
        <button
          onClick={() => {
            setShowSetting(false);
          }}
          className={styles.closeBtn}
        >
          关闭
        </button>
      </div>
    );
  } else {
    return (
      <button
        className={styles.btnSetting}
        onClick={() => setShowSetting(true)}
        title="设置"
      >
        设置
      </button>
    );
  }
};

export default SettingModal;
