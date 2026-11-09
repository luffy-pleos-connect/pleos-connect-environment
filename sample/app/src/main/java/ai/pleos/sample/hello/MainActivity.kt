package ai.pleos.sample.hello

import ai.pleos.playground.vehicle.Vehicle
import ai.pleos.playground.vehicle.api.model.area.DoorArea
import ai.pleos.playground.vehicle.constant.area.DoorValue
import android.app.Activity
import android.car.Car
import android.car.drivingstate.CarUxRestrictions
import android.car.drivingstate.CarUxRestrictionsManager
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.widget.TextView

/**
 * Pleos Getting Started 예제: 운전석(ROW_1_LEFT) 문 위치를 조회해 화면에 표시합니다.
 * https://document.pleos.ai/docs/pleos-only/getting-started
 *
 * 매니페스트에 distractionOptimized 를 선언했으므로 주행 중에도 표시됩니다.
 * 이 화면은 읽기 전용 텍스트 한 줄이라 입력·영상·설정 기능이 없고, 주행 규제 중 적용할 항목은
 * 문자열 길이 제한(UX_RESTRICTIONS_LIMIT_STRING_LENGTH)뿐입니다.
 * https://document.pleos.ai/docs/pleos-only/vehicle-app-developer-guide/driving-restriction-development-guide
 */
class MainActivity : Activity() {

    private lateinit var vehicle: Vehicle
    private lateinit var output: TextView

    private var car: Car? = null
    private var uxRestrictionsManager: CarUxRestrictionsManager? = null
    private var uxRestrictions: CarUxRestrictions? = null

    /** 마지막으로 받은 전체 메시지. 주행 규제에 따라 잘라서 표시합니다. */
    private var message: String = "Vehicle SDK 초기화 중..."

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        output = TextView(this).apply {
            textSize = 32f
            gravity = Gravity.CENTER
        }
        setContentView(output)
        render()

        vehicle = Vehicle(this)
        vehicle.initialize()

        vehicle.getDoor().getCurrentDoorPosition(
            area = DoorArea(DoorValue.ROW_1_LEFT),
            onComplete = { position: Int? ->
                Log.d(TAG, "ROW_1_LEFT door position = $position")
                runOnUiThread { message = "운전석 문 위치: $position"; render() }
            },
            onFailed = { e: Exception ->
                Log.e(TAG, "getCurrentDoorPosition failed", e)
                runOnUiThread { message = "조회 실패: ${e.message}"; render() }
            },
        )
    }

    override fun onStart() {
        super.onStart()
        // 주행 규제 상태 수신: 플랫폼이 지역별로 맞는 ActiveRestrictions 를 내려줍니다.
        car = Car.createCar(this, null, Car.CAR_WAIT_TIMEOUT_DO_NOT_WAIT) { connected, ready ->
            if (!ready) {
                uxRestrictionsManager = null
                return@createCar
            }
            val manager = connected.getCarManager(Car.CAR_UX_RESTRICTION_SERVICE) as? CarUxRestrictionsManager
                ?: return@createCar
            uxRestrictionsManager = manager
            manager.registerListener { restrictions -> runOnUiThread { onUxRestrictionsChanged(restrictions) } }
            runOnUiThread { onUxRestrictionsChanged(manager.currentCarUxRestrictions) }
        }
    }

    override fun onStop() {
        uxRestrictionsManager?.unregisterListener()
        uxRestrictionsManager = null
        car?.disconnect()
        car = null
        super.onStop()
    }

    override fun onDestroy() {
        // 콜백이 비동기이므로 요청 직후가 아니라 화면 종료 시 해제합니다.
        vehicle.release()
        super.onDestroy()
    }

    private fun onUxRestrictionsChanged(restrictions: CarUxRestrictions?) {
        uxRestrictions = restrictions
        Log.d(
            TAG,
            "UX restrictions: requiresDO=${restrictions?.isRequiresDistractionOptimization} " +
                "active=${restrictions?.activeRestrictions}",
        )
        render()
    }

    private fun render() {
        val r = uxRestrictions
        val limited = r != null && r.isRequiresDistractionOptimization &&
            (r.activeRestrictions and CarUxRestrictions.UX_RESTRICTIONS_LIMIT_STRING_LENGTH) != 0
        val max = r?.maxRestrictedStringLength ?: 0
        output.text = if (limited && max > 0 && message.length > max) {
            message.take(max - 1) + "…"
        } else {
            message
        }
    }

    private companion object {
        const val TAG = "PleosHello"
    }
}
