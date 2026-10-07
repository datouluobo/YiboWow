import { useState } from "react";
import "./prototype.css";

const roles = [
  ["天堂暴风", "莫格莱尼", "mage", 27, 18, "42.8 金", "约 2.4 天", "完整 · 10-04 08:20", "critical", "2"],
  ["天堂雷霆", "莫格莱尼", "warrior", 4, 3, "—", "约 5.9 天", "完整 · 10-04 09:10", "warning", ""],
  ["天堂血月", "莫格莱尼", "priest", 19, 13, "6.2 金", "约 10.8 天", "待核实 3 · 10-04 07:42", "", "3"],
  ["天堂闪光", "莫格莱尼", "rogue", 7, 7, "—", "约 13.9 天", "完整 · 10-04 09:51", "", ""],
  ["天堂风暴", "莫格莱尼", "hunter", 2, 2, "1.4 金", "约 17.9 天", "完整 · 10-04 10:10", "", ""],
  ["天堂猎影", "克罗米", "druid", 12, 8, "—", "约 22.6 天", "部分 18/24 · 10-04 13:39", "", ""],
  ["暴风药剂店", "莫格莱尼", "monk", 58, 42, "128.5 金", "约 19.8 天", "完整 · 10-04 06:41", "", ""],
];
const mails = [["拍卖行", "拍卖已售出：奥法之尘", "金币 42.8 金 · 约 2.4 天"], ["公会仓库", "给你留的材料", "奥法之尘 ×12 · 梦境碎片 ×3"], ["暴风城银行", "转寄的物资", "符文布卷 ×4"]];

export function App() {
  const [mode, setMode] = useState("fused");
  const [selected, setSelected] = useState(0);
  const [expanded, setExpanded] = useState(true);
  const [reminder, setReminder] = useState(true);
  const fused = mode === "fused";
  return <main className="stage">
    <header className="topline"><div className="brand"><img src="/yibomail-icon.png"/><div><b>悬停融合预览</b><small>YiboMail · 邮件助手</small></div></div><div className="controls"><button className={fused ? "active" : ""} onClick={() => setMode("fused")}>旧新融合</button><button className={!fused ? "active" : ""} onClick={() => setMode("compact")}>四列精简</button></div></header>
    <section className="layout">
      <aside className="game-side"><div className="side-head">艾泽拉斯 · 插件入口</div><div className="side-content"><div className="character"><small>当前角色</small><b>天堂暴风</b><span>莫格莱尼 · 法师</span></div><div className="broker"><img src="/yibomail-icon.png"/><div><b>[Yibo] 邮件助手</b><span>27 封未收邮件</span></div><i>●</i></div><div className="hover-note"><span>⌖</span><div><b>Broker 悬停预览</b><small>此处模拟指针停留状态</small></div></div><div className="reminder-option"><span>登录时提醒</span><button onClick={() => setReminder(!reminder)} className={reminder ? "switch on" : "switch"}><i/></button></div><div className="note">提醒按上次成功扫描估算。角色切换或重载时，同一风险当天只提示一次。</div></div></aside>
      <section className="preview"><header className="preview-head"><div><img src="/yibomail-icon.png"/><b>YiboMail · 邮件助手</b><small>Broker 悬停预览</small></div><nav><button>克罗米</button><button>莫格莱尼</button><button className="picked">所有服务器</button></nav></header>
        <div className="preview-content"><div className="meta"><b>{fused ? "融合视图" : "精简视图"}</b><span>7 个有效角色快照 · Core 排序</span></div>
          {fused && reminder && <div className="alert"><b>即将到期</b><span>天堂暴风 · 1 封邮件约 2.4 天内到期</span><button>打开邮件页 →</button></div>}
          <div className={`table ${fused ? "fused" : "compact"}`}><div className="thead"><span>角色</span><span>邮件数</span>{fused && <><span>附件数</span><span>可收金币</span></>}<span>最早到期</span><span>更新状态</span></div>
            {roles.map((r, i) => <div key={r[0]} className={selected === i ? "selected-role" : ""}><button className="tr" onClick={() => { if (selected === i) setExpanded(!expanded); else { setSelected(i); setExpanded(true); } }}><span className="name"><b className={r[2]}>{r[0]}</b><small>· {r[1]}</small></span><span>{r[3]}</span>{fused && <><span className="subtle">{r[4]}</span><span className="subtle">{r[5]}</span></>}<span className={`expiry ${r[8]}`}>{r[6]}</span><span className="status">{r[7]}{fused && r[9] && <small>积压 {r[9]}</small>}</span></button>
              {expanded && selected === i && <div className="details"><div className="detail-head"><b>{r[0]} · 最近邮件</b><span>缓存只读 · 不在悬停中收取</span><button onClick={() => setExpanded(false)}>收起</button></div>{mails.map(m => <div className="mail" key={m[1]}><b>{m[0]}</b><span>{m[1]}</span><small>{m[2]}</small></div>)}<button className="open-page">左键打开账号页查看更多　→</button></div>}</div>)}
          </div><footer><span>预览列可在 Core「显示与入口」调整 · 悬停最多显示 20 名</span><button onClick={() => setExpanded(!expanded)}>{expanded ? "收起明细" : "展开所选角色"}</button></footer>
        </div>
      </section>
    </section><div className="legend"><span><i className="red"/>3 天内 · 紧急</span><span><i className="amber"/>7 天内 · 提醒</span><span><i className="normal"/>超过 7 天 · 常规</span><small>切换「旧新融合 / 四列精简」比较信息密度</small></div>
  </main>;
}
