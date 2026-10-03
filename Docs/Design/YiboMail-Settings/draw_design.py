"""Generate a vector layout and its PNG preview from the same geometry."""
from pathlib import Path
from html import escape
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent
S = 2
BG, PANEL, LINE, TEXT, MUTED, GREEN = '#061319', '#0a2027', '#28545a', '#e6f5f7', '#a1bdc3', '#20e070'
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.image = Image.new('RGB', (w*S, h*S), BG)
        self.draw = ImageDraw.Draw(self.image)
        self.svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">', f'<rect width="{w}" height="{h}" fill="{BG}"/>']
        self.measures = []
    def rect(self, x, y, w, h, fill=PANEL, stroke=LINE):
        self.draw.rectangle((x*S,y*S,(x+w)*S,(y+h)*S), fill=fill, outline=stroke, width=S)
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}"/>')
    def line(self, x, y, x2, y2, color=LINE):
        self.draw.line((x*S,y*S,x2*S,y2*S), fill=color, width=S)
        self.svg.append(f'<path d="M{x} {y} L{x2} {y2}" fill="none" stroke="{color}"/>')
    def text(self, x, y, value, size=14, color=TEXT, bold=False, width=None, align='left'):
        font = ImageFont.truetype(BOLD if bold else FONT, size*S)
        natural = self.draw.textlength(value, font=font)/S
        shown = value
        if width is not None and natural > width:
            while shown and self.draw.textlength(shown+'…', font=font)/S > width: shown = shown[:-1]
            shown += '…'
        actual = self.draw.textlength(shown, font=font)/S
        if align == 'center': x -= actual/2
        self.draw.text((x*S,y*S), shown, font=font, fill=color, anchor='lt')
        self.svg.append(f'<text x="{x}" y="{y+size}" font-family="Microsoft YaHei" font-size="{size}" font-weight="{700 if bold else 400}" fill="{color}">{escape(shown)}</text>')
        self.measures.append((value, size, round(natural,1), width))
    def button(self,x,y,w,label,kind='normal'):
        fill, stroke = ('#104032', GREEN) if kind=='primary' else (('#30191e','#9a414c') if kind=='danger' else (PANEL,LINE))
        self.rect(x,y,w,34,fill,stroke); self.text(x+w/2,y+9,label,16,MUTED if kind=='disabled' else TEXT,bold=True,align='center',width=w-24)
    def input(self,x,y,w,value,placeholder=False):
        self.rect(x,y,w,34,'#05161c',LINE); self.text(x+12,y+10,value,14,MUTED if placeholder else TEXT,width=w-24)
    def dropdown(self,x,y,w,value):
        self.rect(x,y,w,34,PANEL,LINE); self.text(x+12,y+10,value,14,width=w-44)
        self.line(x+w-23,y+15,x+w-18,y+20,MUTED); self.line(x+w-18,y+20,x+w-13,y+15,MUTED)
    def check(self,x,y,label,checked=True,size=14):
        self.rect(x,y,20,20,GREEN if checked else BG,GREEN if checked else LINE)
        if checked: self.line(x+4,y+10,x+8,y+14,'#042315'); self.line(x+8,y+14,x+16,y+5,'#042315')
        self.text(x+28,y+3,label,size,TEXT)
    def section(self,x,y,w,h,title):
        self.rect(x,y,w,h); self.text(x+16,y+14,title,16,GREEN,True); self.line(x+16,y+40,x+w-16,y+40)
    def save(self,name):
        self.image.resize((self.w,self.h),Image.Resampling.LANCZOS).save(OUT/(name+'.png'))
        (OUT/(name+'.svg')).write_text('\n'.join(self.svg+['</svg>']),encoding='utf-8')


def icon(c,x,y,size,kind='cloth'):
    c.rect(x,y,size,size,'#14313a','#537478')
    # Concept-only item illustrations; production uses the client's item texture.
    if kind=='cloth':
        for dx,dy,w,h in [(5,5,19,9),(8,12,18,9),(5,19,19,8)]:
            k=size/32; c.rect(x+dx*k,y+dy*k,w*k,h*k,'#b9c9bb','#596f66')
            c.line(x+(dx+3)*k,y+(dy+2)*k,x+(dx+w-3)*k,y+(dy+2)*k,'#809b90')
    else:
        k=size/32
        for dx,dy,w,h in [(5,9,13,14),(15,5,12,15),(14,19,12,8)]:
            c.rect(x+dx*k,y+dy*k,w*k,h*k,'#679a9d','#acd4c4')

c=Canvas(1312,840)
c.rect(0,0,1312,48,'#0b242c','#0b242c'); c.text(20,16,'YiboCore · 设置',18,bold=True)
c.button(1180,7,82,'设置'); c.text(1280,16,'×',18,'#ef8d96')
c.rect(0,48,176,792,'#081b22','#081b22'); c.text(16,70,'‹ 返回邮件',14,MUTED); c.text(16,110,'Core 常规设置',14,GREEN,True)
for y,label in [(152,'窗口'),(192,'角色与排序'),(232,'显示与入口'),(292,'角色构筑'),(332,'专业制造'),(372,'货币总览'),(412,'传说之路')]: c.text(24,y,label,14)
c.rect(8,448,160,36,'#123b3e','#123b3e'); c.text(24,458,'邮件',14,bold=True)
for y,label in [(504,'任务屏蔽'),(544,'声望总览'),(584,'账号待办'),(624,'物品总览')]: c.text(24,y,label,14)
c.text(192,68,'邮件业务设置',18,bold=True); c.text(192,96,'规则指定物品与收件人；发件箱按每封最多 12 个附件提供装填建议。',14,MUTED)
c.section(192,128,692,628,'寄送规则 · 共 237 条')
c.input(208,182,424,'搜索物品名称 / ID / 收件人',True); c.button(644,182,128,'新建规则','primary'); c.button(780,182,88,'清除筛选')
c.dropdown(208,228,344,'全部收件人'); c.dropdown(564,228,148,'全部状态'); c.dropdown(724,228,144,'物品名称 ↑')
c.rect(208,280,660,28,'#102d34','#102d34')
for x,label in [(252,'物品 / ID'),(468,'收件人'),(672,'状态'),(780,'操作')]: c.text(x,288,label,12,MUTED)
examples = [('风绒绷带',72985,'天堂风暴-同服',True),('附魔武器－舞钢 · 长名称示例',74726,'天堂闪光-同服',True),
    ('魔古财宝钥匙',94222,'天堂魔影-同服',False),('风绒布',72988,'天堂风暴-同服',True),('幽冥铁矿石',72092,'天堂闪光-同服',True),
    ('绿茶叶',72234,'天堂风暴-同服',True),('黄金莲',72238,'天堂魔影-同服',False),('灵魂尘',74249,'天堂闪光-同服',True),('日长石',76134,'天堂风暴-同服',True)]
examples.sort(key=lambda row: row[0])
for i,(name,ident,recipient,enabled) in enumerate(examples):
    y=308+i*42; c.rect(208,y,660,42,'#0b242c' if i%2==0 else '#102b33','#173c44')
    icon(c,216,y+7,28,'cloth' if ident in [72985,72988] else 'stone')
    c.text(252,y+5,name,14,width=204); c.text(252,y+24,str(ident),12,MUTED)
    c.text(468,y+14,recipient,14,width=192); c.check(672,y+11,'启用' if enabled else '停用',enabled,12); c.button(780,y+4,88,'编辑')
c.button(208,706,72,'上一页','disabled'); c.button(288,706,72,'下一页'); c.text(376,716,'1 / 27 页',14,MUTED)
c.input(488,706,56,'1'); c.button(556,706,72,'跳转'); c.text(648,716,'显示 1–9 / 237 条',14,MUTED,width=220)

c.section(900,128,396,520,'新建规则')
c.text(916,181,'物品 *',14,MUTED)
for x,w,label in [(916,88,'物品 ID'),(1016,72,'名字'),(1100,72,'背包'),(1184,96,'拖放')]:
    c.button(x,204,w,label,'primary' if label=='名字' else 'normal')
c.input(916,254,264,'风绒绷带'); c.button(1192,254,88,'查找')
icon(c,916,302,40,'cloth'); c.text(968,304,'风绒绷带',16,bold=True,width=312); c.text(968,327,'物品 ID 72985 · 已选定',12,MUTED,width=312)
c.dropdown(916,362,364,'搜索结果 · 风绒绷带（72985）')
c.text(916,411,'收件人 *',14,MUTED); c.dropdown(916,434,364,'选择其它角色 / 规则收件人')
c.input(916,480,364,'天堂风暴'); c.text(916,524,'保存地址：天堂风暴-当前服务器（同服）',12,MUTED,width=364)
c.check(916,550,'启用规则',True); c.text(1068,553,'必填：物品、收件人',12,MUTED,width=212)
c.button(916,598,128,'保存规则','primary'); c.button(1056,598,112,'取消编辑'); c.button(1180,598,100,'联系人')
c.section(900,664,396,92,'数据与缓存')
c.text(916,725,'历史 90 天 · 待核实 30 天',12,MUTED,width=248); c.button(1192,710,88,'管理')
c.text(192,778,'图标位置与尺寸已预留；概念图图标为示意，正式界面读取游戏物品图标。',14,MUTED,width=1104)
c.text(192,812,'设计状态：待确认 · 同服为示例标记，实际显示所属服务器名称。',12,MUTED)
c.save('YiboMail-规则设置-待确认')

d=Canvas(1312,690)
d.text(32,28,'YiboMail · 规则条件与控件尺寸',24,bold=True)
d.text(32,70,'规则必填：物品、收件人。输入方式影响选取过程，最终保存稳定的物品 ID 与完整收件地址。',14,MUTED)
d.section(32,114,610,250,'物品：四种添加方式')
for y,label in [(174,'ID：输入数字，读取名称与图标后选定。'),(216,'名字：搜索已知物品，选择明确的候选。'),(258,'背包：从可寄送物品下拉中选择。'),(300,'拖放：把物品拖到图标区，读取完整物品身份。')]: d.text(48,y,label,16,width=578)
d.section(658,114,622,250,'收件人：选择或手工填写')
for y,label in [(174,'下拉来源：其它账号角色、已有规则收件人、收藏联系人。'),(216,'名单按完整地址去重，标记来源，支持搜索和分页。'),(258,'手工地址未包含服务器：保存时补当前角色所在服务器。'),(300,'手工输入与名单选择共用同一地址，始终显示解析结果。')]: d.text(674,y,label,14,width=590)
d.section(32,380,1248,268,'控件预算与长期使用')
for y,label in [(438,'列表列宽：物品 260 + 收件人 204 + 状态 108 + 编辑 88 = 660；规则行高 42。'),
(478,'编辑区内部 364：方式按钮 88 + 12 + 72 + 12 + 72 + 12 + 96；查询 264 + 12 + 88。'),
(518,'输入、下拉、按钮高 34；拖放与已选物品图标 40 × 40；列表物品图标 28 × 28。'),
(558,'缓存常驻区 396 × 92：摘要 + 管理；展开为 Core 托管的分页／分区内容，删除操作放末尾。'),
(598,'列表按可用高度分页，搜索覆盖全部规则；窄屏先显示列表，点击编辑进入同一内容区的表单。')]: d.text(48,y,label,14,width=1216)
d.save('YiboMail-规则设置尺寸-待确认')
print('Updated rule settings concept and dimensions.')
