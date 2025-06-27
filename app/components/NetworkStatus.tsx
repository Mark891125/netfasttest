import { useState, useEffect } from 'react';

interface NetworkStatusProps {
  className?: string;
}

interface NetworkStatus {
  online: boolean;
  effectiveType?: string;
  downlink?: number;
  rtt?: number;
}

// 扩展Navigator接口以支持网络连接API
interface ExtendedNavigator extends Navigator {
  connection?: {
    effectiveType?: string;
    downlink?: number;
    rtt?: number;
    addEventListener?: (type: string, listener: () => void) => void;
    removeEventListener?: (type: string, listener: () => void) => void;
  };
  mozConnection?: {
    effectiveType?: string;
    downlink?: number;
    rtt?: number;
  };
  webkitConnection?: {
    effectiveType?: string;
    downlink?: number;
    rtt?: number;
  };
}

export default function NetworkStatus({ className }: NetworkStatusProps) {
  const [networkStatus, setNetworkStatus] = useState<NetworkStatus>({
    online: true
  });

  useEffect(() => {
    const updateNetworkStatus = () => {
      const extNavigator = navigator as ExtendedNavigator;
      const connection = extNavigator.connection || extNavigator.mozConnection || extNavigator.webkitConnection;
      
      setNetworkStatus({
        online: navigator.onLine,
        effectiveType: connection?.effectiveType,
        downlink: connection?.downlink,
        rtt: connection?.rtt
      });
    };

    // 初始化状态
    updateNetworkStatus();

    // 监听网络状态变化
    window.addEventListener('online', updateNetworkStatus);
    window.addEventListener('offline', updateNetworkStatus);
    
    // 监听网络信息变化（如果支持）
    const extNavigator = navigator as ExtendedNavigator;
    const connection = extNavigator.connection;
    if (connection && connection.addEventListener) {
      connection.addEventListener('change', updateNetworkStatus);
    }

    return () => {
      window.removeEventListener('online', updateNetworkStatus);
      window.removeEventListener('offline', updateNetworkStatus);
      if (connection && connection.removeEventListener) {
        connection.removeEventListener('change', updateNetworkStatus);
      }
    };
  }, []);

  const getStatusColor = () => {
    if (!networkStatus.online) return '#dc3545';
    if (networkStatus.effectiveType === '4g') return '#28a745';
    if (networkStatus.effectiveType === '3g') return '#ffc107';
    return '#6c757d';
  };

  const getStatusText = () => {
    if (!networkStatus.online) return '离线';
    if (networkStatus.effectiveType) {
      return `${networkStatus.effectiveType.toUpperCase()}`;
    }
    return '在线';
  };

  return (
    <div className={className} style={{ 
      display: 'flex', 
      alignItems: 'center', 
      gap: '8px',
      fontSize: '14px',
      color: '#666'
    }}>
      <div 
        style={{
          width: '8px',
          height: '8px',
          borderRadius: '50%',
          backgroundColor: getStatusColor()
        }}
      />
      <span>{getStatusText()}</span>
      {networkStatus.downlink && (
        <span style={{ fontFamily: 'var(--font-geist-mono)' }}>
          ({networkStatus.downlink} Mbps)
        </span>
      )}
      {networkStatus.rtt && (
        <span style={{ fontFamily: 'var(--font-geist-mono)' }}>
          RTT: {networkStatus.rtt}ms
        </span>
      )}
    </div>
  );
}
