#ifndef MAIN_SRC_BLE_INITBLE_H_
#define MAIN_SRC_BLE_INITBLE_H_

//#include <stdio.h>
//#include <stdlib.h>
//#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_event.h"
#include "nvs_flash.h"
#include "esp_log.h"
#include "esp_nimble_hci.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
#include "services/ans/ble_svc_ans.h"
#include "sdkconfig.h"
#include "esp_bt.h"
#include "initFLASH.h"

#include "DS1340.h"
#include "MyStruct.h"

static const ble_uuid128_t SERVICE_UUID =
    BLE_UUID128_INIT(0xe2, 0x5b, 0x4e, 0x5d, 0x86, 0x34, 0x00, 0x80,
                     0x00, 0x10, 0x00, 0x00, 0x0a, 0x18, 0x00, 0x00);

/* 5c3a659e-897e-45e1-b016-007107c96df6 */
static const ble_uuid128_t CHARACTERISTIC_UUID =
    BLE_UUID128_INIT(0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
                     0x00, 0x10, 0x00, 0x00, 0x0d, 0x2b, 0x00, 0x00);

/*  */
static const ble_uuid128_t CHARACTERISTICstatus_UUID =
    BLE_UUID128_INIT(0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
                     0x00, 0x10, 0x00, 0x00, 0x05, 0x2b, 0x00, 0x00);

static const ble_uuid128_t CHARACTERISTICheat_UUID =
    BLE_UUID128_INIT(0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
                     0x00, 0x10, 0x00, 0x00, 0x18, 0x2b, 0x00, 0x00);

static const ble_uuid128_t CHARACTERISTICend_UUID =
    BLE_UUID128_INIT(0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
                     0x00, 0x10, 0x00, 0x00, 0x44, 0x2b, 0x00, 0x00);

/* */
static const ble_uuid128_t CHARACTERISTICback_UUID =
    BLE_UUID128_INIT(0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
                     0x00, 0x10, 0x00, 0x00, 0x45, 0x2b, 0x00, 0x00);

static int device_read_void(uint16_t con_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
void notify_over_control_chr(int16_t conn_handle, char* data);
void gatt_svr_register_cb(struct ble_gatt_register_ctxt *ctxt, void *arg);
void MyDataBLESend(uint8_t TimeSec);
static int device_write(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
static int device_read(uint16_t con_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg);
static int ble_gap_event(struct ble_gap_event *event, void *arg);
void ble_app_advertise(void);
void ble_app_on_sync(void);
static void host_task(void *param);
void InitBLE(struct _DataToSend *DataToSend, struct _DataWiFiServer *DataWiFiServer, struct _SistemFlags *SistemFlags, struct _PositionGUI * NumberGUI);

uint8_t get_control_notif_handle(void);
uint8_t get_flag_connect_and_Notify(void);

void BLEenble(void);
void BLEdisable(void);

#endif /* MAIN_SRC_BLE_INITBLE_H_ */
