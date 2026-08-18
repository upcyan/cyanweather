package com.cyanweather.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cyanweather.app.update.UpdateResult

@Composable
fun UpdateDialog(
    result: UpdateResult.UpdateAvailable,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("发现新版本 v${result.version}", fontWeight = FontWeight.Bold, style = fst(24))
        },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Text("更新日志：", style = fst(18), fontWeight = FontWeight.Medium)
                Spacer(Modifier.height(8.dp))
                Text(result.releaseNotes.ifBlank { "暂无更新说明" }, style = fst(16))
                if (result.fileSize > 0) {
                    Spacer(Modifier.height(8.dp))
                    val sizeMB = result.fileSize / 1024.0 / 1024.0
                    Text("安装包大小：${String.format("%.1f", sizeMB)} MB", style = fst(14), color = androidx.compose.ui.graphics.Color(0xFF666666))
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text("立即更新", style = fst(18))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("稍后", style = fst(18))
            }
        }
    )
}
