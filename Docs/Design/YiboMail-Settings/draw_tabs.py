from pathlib import Path

# Share the measured controls and vector/PNG renderer with the preceding draft.
exec((Path(__file__).parent/'draw_design.py').read_text(encoding='utf-8').split('c=Canvas')[0], globals())

def shell(active, subtitle):
    c=Canvas(1312,840)
    c.rect(0,0,1312,48,'#0b242c','#0b242c'); c.text(20,16,'YiboCore · 设置',18,bold=True)
    c.button(1180,7,82,'设置'); c.text(1280,16,'×',18,'#ef8d96')
    c.rect(0,48,176,792,'#081b22','#081b22'); c.text(16,70,'‹ 返回邮件',14,MUTED); c.text(16,110,'Core 常规设置',14,GREEN,True)
    for y,label in [(152,'窗口'),(192,'角色与排序'),(232,'显示与入口'),(292,'角色构筑'),(332,'专业制造'),(372,'货币总览'),(412,'传说之路')]: c.text(24,y,label,14)
    c.rect(8,448,160,36,'#123b3e','#123b3e'); c.text(24,458,'邮件',14,bold=True)
    for y,label in [(504,'任务屏蔽'),(544,'声望总览'),(584,'账号待办'),(624,'物品总览')]: c.text(24,y,label,14)
    c.text(192,68,'邮件业务设置',18,bold=True); c.text(192,96,subtitle,14,MUTED,width=1104)
    for x,w,label in [(192,112,'发件'),(316,112,'收件'),(440,144,'缓存管理')]: c.button(x,122,w,label,'primary' if label==active else 'normal')
    return c

c=shell('发件','设置发件规则；物品与收件人为必填，按每封最多 12 个附件提供装填建议。')
c.section(192,176,692,580,'发件规则 · 共 237 条')
c.input(208,232,424,'搜索物品名称 / ID / 收件人',True); c.button(644,232,128,'新建规则','primary'); c.button(780,232,88,'清除筛选')
c.dropdown(208,278,344,'全部收件人'); c.dropdown(564,278,148,'全部状态'); c.dropdown(724,278,144,'物品名称 ↑')
c.rect(208,328,660,28,'#102d34','#102d34')
for x,label in [(252,'物品 / ID'),(468,'收件人'),(672,'状态'),(780,'操作')]: c.text(x,336,label,12,MUTED)
examples=[('幽冥铁矿石',72092,'天堂闪光-同服',True),('日长石',76134,'天堂风暴-同服',True),('灵魂尘',74249,'天堂闪光-同服',True),
          ('绿茶叶',72234,'天堂风暴-同服',True),('附魔武器－舞钢 · 长名称示例',74726,'天堂闪光-同服',True),('风绒布',72988,'天堂风暴-同服',True),
          ('风绒绷带',72985,'天堂风暴-同服',True),('魔古财宝钥匙',94222,'天堂魔影-同服',False)]
for i,(name,ident,recipient,enabled) in enumerate(examples):
    y=356+i*42; c.rect(208,y,660,42,'#0b242c' if i%2==0 else '#102b33','#173c44')
    icon(c,216,y+7,28,'cloth' if ident in [72985,72988] else 'stone')
    c.text(252,y+5,name,14,width=204); c.text(252,y+24,str(ident),12,MUTED)
    c.text(468,y+14,recipient,14,width=192); c.check(672,y+11,'启用' if enabled else '停用',enabled,12); c.button(780,y+4,88,'编辑')
c.button(208,706,72,'上一页','disabled'); c.button(288,706,72,'下一页'); c.text(376,716,'1 / 30 页',14,MUTED)
c.input(488,706,56,'1'); c.button(556,706,72,'跳转'); c.text(648,716,'显示 1–8 / 237 条',14,MUTED,width=220)
c.section(900,176,396,580,'新建发件规则')
c.text(916,234,'物品 *',14,MUTED)
for x,w,label in [(916,88,'物品 ID'),(1016,72,'名字'),(1100,72,'背包'),(1184,96,'拖放')]: c.button(x,266,w,label,'primary' if label=='名字' else 'normal')
c.input(916,320,264,'风绒绷带'); c.button(1192,320,88,'查找')
icon(c,916,384,40,'cloth'); c.text(968,386,'风绒绷带',16,bold=True,width=312); c.text(968,409,'物品 ID 72985 · 已选定',12,MUTED,width=312)
c.dropdown(916,444,364,'搜索结果 · 风绒绷带（72985）')
c.text(916,500,'收件人 *',14,MUTED); c.dropdown(916,528,364,'选择其它角色 / 规则收件人')
c.input(916,578,364,'天堂风暴'); c.text(916,628,'保存地址：天堂风暴-当前服务器（同服）',12,MUTED,width=364)
c.check(916,660,'启用规则',True); c.text(1068,663,'必填：物品、收件人',12,MUTED,width=212)
c.button(916,706,128,'保存规则','primary'); c.button(1056,706,112,'取消编辑'); c.button(1180,706,100,'联系人')
c.text(192,778,'列表搜索覆盖全部规则；编辑保持筛选和页码。联系人管理位于本页的“联系人”入口。',14,MUTED,width=1104)
c.text(192,812,'设计状态：待确认 · 示例图标与同服标记将在接入时替换为实际游戏信息。',12,MUTED)
c.save('YiboMail-发件标签页-待确认')

r=shell('收件','设置原生收件箱的默认视图和收取偏好；批量收取先预览，再由玩家确认。')
r.section(192,176,692,276,'默认视图')
r.text(208,234,'初始展示',14,MUTED); r.button(208,260,112,'邮件','primary'); r.button(332,260,112,'附件')
r.text(208,316,'默认排序',14,MUTED); r.text(548,316,'默认邮件类别',14,MUTED)
r.dropdown(208,344,328,'临期优先'); r.dropdown(548,344,320,'全部邮件')
r.check(208,408,'再次打开邮箱时保留搜索与筛选',False)
r.section(192,468,692,288,'批量收取偏好')
r.text(208,526,'“全选可收项目”的默认范围',14,MUTED)
r.check(208,560,'物品附件',True); r.check(420,560,'邮件金币',True)
r.text(208,608,'选择结果仍可在原生邮箱中逐项调整。',14,MUTED,width=660)
r.check(208,642,'收取完成后显示本批结果摘要',True)
r.button(208,706,144,'保存收件设置','primary'); r.button(364,706,128,'恢复默认')
r.section(900,176,396,380,'收取处理方式')
for y,title,detail in [(234,'操作角色','只操作当前角色的可见邮件。'),(292,'付款取信（COD）','通过原生信件确认付款。'),(350,'身份不明确的重复邮件','等待核实，暂不加入收取批次。'),
                       (408,'邮箱关闭或内容发生变化','暂停队列，保留未执行项目。'),(466,'背包不足或操作失败','显示原因，核实后重新预览。')]:
    r.text(916,y,title,14,bold=True,width=364); r.text(916,y+24,detail,12,MUTED,width=364)
r.section(900,572,396,184,'使用流程')
r.text(916,626,'选择项目 → 预览批次 → 确认收取',14,width=364)
r.text(916,664,'暂停后：核实结果 → 重新预览剩余项目',12,MUTED,width=364)
r.text(916,706,'邮件历史及缓存期限在“缓存管理”页。',12,MUTED,width=364)
r.text(192,778,'收件设置作用于原生邮箱增强；账号页面、入口、角色与字段配置仍由 Core 管理。',14,MUTED,width=1104)
r.text(192,812,'设计状态：待确认 · 收件偏好设计稿。',12,MUTED)
r.save('YiboMail-收件标签页-待确认')
print('Generated outgoing and incoming tab concepts.')
