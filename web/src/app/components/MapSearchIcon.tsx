// Custom Map Search Icon - 虫眼鏡の中にピン
export function MapSearchIcon({ size = 24, color = 'currentColor' }: { size?: number; color?: string }) {
  return (
    <svg 
      width={size} 
      height={size} 
      viewBox="0 0 24 24" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* 虫眼鏡の円 */}
      <circle 
        cx="10.5" 
        cy="10.5" 
        r="7" 
        stroke={color} 
        strokeWidth="2" 
        strokeLinecap="round"
      />
      
      {/* 虫眼鏡の柄 */}
      <path 
        d="M15.5 15.5L20 20" 
        stroke={color} 
        strokeWidth="2" 
        strokeLinecap="round"
      />
      
      {/* ピン（中央） */}
      <path 
        d="M10.5 7.5C9.67 7.5 9 8.17 9 9C9 9.83 10.5 12 10.5 12C10.5 12 12 9.83 12 9C12 8.17 11.33 7.5 10.5 7.5Z" 
        fill={color}
      />
      <circle 
        cx="10.5" 
        cy="9" 
        r="0.8" 
        fill="white"
      />
    </svg>
  );
}
