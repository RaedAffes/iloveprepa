"use client";

export default function ContactIllustration() {
  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        aspectRatio: "790 / 563",
        flexShrink: 0,
      }}
    >
      <img
        src="/illustrations/contact_art.svg"
        alt=""
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          objectFit: "contain",
        }}
      />
      <svg
        viewBox="0 0 790 563"
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
        aria-hidden
      >
        <g>
          <circle cx={687} cy={87} r={9} fill="#FF923C" style={{ opacity: 0 }}>
            <animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.1s" repeatCount="indefinite" />
          </circle>
          <circle cx={734} cy={146} r={6} fill="#FF923C" style={{ opacity: 0 }}>
            <animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.1s" repeatCount="indefinite" />
          </circle>
          <circle cx={68} cy={420} r={8} fill="#FF923C" style={{ opacity: 0 }}>
            <animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.5s" repeatCount="indefinite" />
          </circle>
          <circle cx={118} cy={64} r={7} fill="#FF923C" style={{ opacity: 0 }}>
            <animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.7s" repeatCount="indefinite" />
          </circle>
          <circle cx={748} cy={488} r={9} fill="#FF923C" style={{ opacity: 0 }}>
            <animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.3s" repeatCount="indefinite" />
          </circle>
          <circle cx={706} cy={524} r={6} fill="#FF923C" style={{ opacity: 0 }}>
            <animate attributeName="opacity" values="0;1;0" dur="1s" begin="0.2s" repeatCount="indefinite" />
          </circle>
          <g style={{ animation: "ip-contact-float 2s ease-in-out infinite alternate" }}>
            <g transform="translate(395, 282)">
              <ellipse cx={0} cy={-26} rx={34} ry={26} fill="#FF923C" />
              <ellipse cx={0} cy={-13} rx={26} ry={13} fill="#FF7A00" />
              <path d="M -34 -26 L 0 -13 L 34 -26 Z" fill="#FFB36B" opacity={0.7} />
            </g>
          </g>
        </g>
      </svg>
    </div>
  );
}