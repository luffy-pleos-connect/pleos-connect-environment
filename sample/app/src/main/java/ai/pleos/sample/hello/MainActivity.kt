package ai.pleos.sample.hello

import ai.pleos.playground.vehicle.Vehicle
import ai.pleos.playground.vehicle.api.model.area.DoorArea
import ai.pleos.playground.vehicle.constant.area.DoorValue
import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.TextView

/**
 * Pleos Getting Started 예제: 운전석(ROW_1_LEFT) 문 위치를 조회해 화면에 표시합니다.
 * https://document.pleos.ai/docs/pleos-only/getting-started
 */
class MainActivity : Activity() {

    private lateinit var vehicle: Vehicle
    private lateinit var output: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        output = TextView(this).apply {
            textSize = 32f
            gravity = Gravity.CENTER
            text = "Vehicle SDK 초기화 중..."
        }
        setContentView(output)

        vehicle = Vehicle(this)
        vehicle.initialize()

        vehicle.getDoor().getCurrentDoorPosition(
            area = DoorArea(DoorValue.ROW_1_LEFT),
            onComplete = { position: Int? ->
                Log.d(TAG, "ROW_1_LEFT door position = $position")
                runOnUiThread { output.text = "운전석 문 위치: $position" }
            },
            onFailed = { e: Exception ->
                Log.e(TAG, "getCurrentDoorPosition failed", e)
                runOnUiThread { output.text = "조회 실패: ${e.message}" }
            },
        )
    }

    override fun onDestroy() {
        // 콜백이 비동기이므로 요청 직후가 아니라 화면 종료 시 해제합니다.
        vehicle.release()
        super.onDestroy()
    }

    private companion object {
        const val TAG = "PleosHello"
    }
}
