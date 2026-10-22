package com.cyanweather.app.data

/**
 * 城市名繁转简。
 * 逆地理编码（bigdatacloud，localityLanguage=zh）返回的中文名混有繁体（如 宿松縣），
 * 任何写入持久化或用于显示的城市名都必须先经过 [simp]。
 */
object CityNameSimplify {
    private val TRAD_TO_SIMP = mapOf(
        "東" to "东", "濟" to "济", "廣" to "广", "陽" to "阳", "陰" to "阴",
        "臺" to "台", "灣" to "湾", "龍" to "龙", "雲" to "云", "島" to "岛",
        "縣" to "县", "區" to "区", "寧" to "宁", "蘇" to "苏", "澤" to "泽",
        "漢" to "汉", "濱" to "滨", "豐" to "丰", "麗" to "丽", "門" to "门",
        "華" to "华", "廈" to "厦", "閩" to "闽", "贛" to "赣", "晉" to "晋",
        "陝" to "陕", "貴" to "贵", "瓊" to "琼", "遼" to "辽", "鄒" to "邹",
        "臨" to "临", "萊" to "莱", "蕪" to "芜", "長" to "长", "慶" to "庆",
        "榮" to "荣", "單" to "单", "費" to "费", "濰" to "潍", "諸" to "诸",
        "兗" to "兖", "嶧" to "峄", "鄆" to "郓", "棲" to "栖", "遠" to "远",
        "樂" to "乐", "無" to "无", "蓮" to "莲", "齊" to "齐", "蘭" to "兰",
        "鄉" to "乡", "膠" to "胶", "黃" to "黄", "饒" to "饶", "興" to "兴",
        "棗" to "枣", "莊" to "庄", "幹" to "干", "烏" to "乌", "雙" to "双",
        "澳" to "澳", "蒼" to "苍", "潁" to "颍", "懷" to "怀", "滬" to "沪",
        "魯" to "鲁", "粵" to "粤", "黔" to "黔", "滇" to "滇", "鄭" to "郑",
        "衛" to "卫", "島" to "岛", "瀘" to "泸", "澗" to "涧", "潯" to "浔",
        "鞏" to "巩", "嶽" to "岳", "鳳" to "凤", "龕" to "龛", "欽" to "钦",
        "賀" to "贺", "婁" to "娄", "紹" to "绍", "興" to "兴", "義" to "义",
        "烏" to "乌", "魯" to "鲁", "齊" to "齐", "哈" to "哈", "爾" to "尔",
        "濱" to "滨", "綏" to "绥", "驛" to "驿", "鎮" to "镇", "鐵" to "铁",
        "嶺" to "岭", "橋" to "桥", "灣" to "湾", "灘" to "滩", "園" to "园"
    )

    fun simp(s: String): String =
        s.map { TRAD_TO_SIMP[it.toString()] ?: it.toString() }.joinToString("")
}
