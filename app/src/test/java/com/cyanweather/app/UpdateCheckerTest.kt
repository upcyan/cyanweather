package com.cyanweather.app

import com.cyanweather.app.update.UpdateChecker
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class UpdateCheckerTest {
    // compareVersions 是 object 内的私有实例方法，通过反射验证版本比较逻辑
    private fun compare(v1: String, v2: String): Int {
        val instance = UpdateChecker::class.java.getDeclaredField("INSTANCE").get(null)
        val m = UpdateChecker::class.java.getDeclaredMethod("compareVersions", String::class.java, String::class.java)
        m.isAccessible = true
        return m.invoke(instance, v1, v2) as Int
    }

    @Test
    fun testCompareVersions() {
        assertTrue(compare("1.3", "1.2") > 0)
        assertTrue(compare("1.10", "1.9") > 0)      // 数字比较而非字符串比较
        assertEquals(0, compare("1.2", "1.2"))
        assertTrue(compare("1.2", "1.2.1") < 0)
        assertTrue(compare("2.0", "1.9.9") > 0)
    }

    @Test
    fun testCompareVersionsWithBuildMeta() {
        assertTrue(compare("1.3+36", "1.2") > 0)    // semver build 元数据
        assertEquals(0, compare("1.2+36", "1.2"))
    }
}
