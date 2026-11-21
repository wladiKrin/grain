package io.github.wladikrin.grain.meter

import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QrDecoderTest {
    @Test fun decodesAQrRenderedIntoAPaddedYPlane() {
        // 1500 printable ASCII characters, varied so the encoder needs byte mode.
        val payload = buildString { repeat(1500) { append('!' + (it * 7) % 94) } }
        val matrix = QRCodeWriter().encode(
            payload, BarcodeFormat.QR_CODE, 0, 0,
            mapOf(EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M, EncodeHintType.MARGIN to 4),
        )
        val px = 4
        val width = matrix.width * px
        val height = matrix.height * px
        val rowStride = width + 16
        // Padding bytes are left at 0x55 so a decoder reading them would see noise.
        val y = ByteArray(rowStride * height) { 0x55 }
        for (row in 0 until height) {
            for (col in 0 until width) {
                y[row * rowStride + col] = if (matrix[col / px, row / px]) 0 else 255.toByte()
            }
        }
        assertEquals(payload, QrDecoder.decode(y, width, height, rowStride))
    }

    @Test fun noCodeGivesNull() {
        val y = ByteArray(640 * 480) { 128.toByte() }
        assertNull(QrDecoder.decode(y, 640, 480, 640))
    }
}
