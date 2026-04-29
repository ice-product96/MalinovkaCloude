#include "initBLE.h"

uint8_t ble_addr_type;

uint16_t control_notif_handle;
uint8_t flag_connect_and_Notify = 0;

struct _DataToSend *pointerDataToSend;
struct _DataWiFiServer *pointerDataWiFiServer;
struct _SistemFlags *pointerSistemFlags;
struct _PositionGUI *pointerPositionGUI;

//static char ble_svc_gatt_read_val_handle[] = "{\"temperature\":\"28\",\"settemperature\":\"100\",\"status\":\"work\",\"timeend\":\"12:00\",\"settimeend\":\"12:30\",\"load\":\"0\",\"modeSmoke\":\"1\",\"nameprog\":\"Мясо\",\"id\":\"34865D4E5BE2";

uint8_t get_control_notif_handle(void)
{
	return ble_addr_type;
}

static int device_write(uint16_t conn_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
	char tmpString[100] = {0};

	uint16_t om_len;

	om_len = OS_MBUF_PKTLEN(ctxt->om);

//	printf("len data ble = %d\n", om_len);

	ble_hs_mbuf_to_flat(ctxt->om, &tmpString, 100, &om_len);

//    printf("char array = %s\n", tmpString);

    if(tmpString[0] == 's' && tmpString[1] == 'e' && tmpString[2] == 't' && tmpString[3] == 't' && tmpString[4] == 'i' && tmpString[5] == 'm' && tmpString[6] == 'e')
    {
    	uint8_t SetTimeArrayBLE[3] = {10, 0, 0};

    	if(tmpString[9] == ';')
    	{
    		SetTimeArrayBLE[0] = tmpString[8] - 48;

    		if(tmpString[11] == ';')
			{
    			SetTimeArrayBLE[1] = tmpString[10] - 48;
			}
    		else
    		{
    			SetTimeArrayBLE[1] = ((tmpString[10] - 48) * 10) + (tmpString[11] - 48);
    		}
    	}
    	else
    	{
    		SetTimeArrayBLE[0] = ((tmpString[8] - 48) * 10) + (tmpString[9] - 48);

    		if(tmpString[12] == ';')
			{
				SetTimeArrayBLE[1] = tmpString[11] - 48;
			}
			else
			{
				SetTimeArrayBLE[1] = ((tmpString[11] - 48) * 10) + (tmpString[12] - 48);
			}
    	}

    	SetTime_DS1340(1, SetTimeArrayBLE);
    	pointerSistemFlags->flagOutTimeToDisp = 0;
    }
    else if(tmpString[0] == 's' && tmpString[1] == 'e' && tmpString[2] == 't' && tmpString[3] == 'u' && tmpString[4] == 'i' && tmpString[5] == 'd')
    {
    	if(tmpString[7] == 'S' && tmpString[8] == '4' && tmpString[9] == '5' && tmpString[10] == 'S' && tmpString[11] == '7' && tmpString[12] == '2')
    	{
    		uint8_t CounterStart = 14;
    		uint8_t len = 0;

    		for(;;)
    		{
    			if(tmpString[CounterStart + len] == ';')
    			{
    				break;
    			}
    			else
    			{
    				len++;
    			}
    		}

    		char TmpUID[100];

    		for(uint8_t CurentCounter = 0; CurentCounter < len; CurentCounter++)
    		{
    			TmpUID[CurentCounter] = tmpString[CounterStart + CurentCounter];
    		}

    		TmpUID[len] = 0;

    		memset(pointerDataWiFiServer->WayToServer, '\0', sizeof pointerDataWiFiServer->WayToServer);

    		memcpy(pointerDataWiFiServer->WayToServer, TmpUID, len);

    		printf("DATA UID - %s\n", TmpUID);
    	}
    }
    else if(tmpString[0] == 's' && tmpString[1] == 'e' && tmpString[2] == 't' && tmpString[3] == 'w' && tmpString[4] == 'i' && tmpString[5] == 'f' && tmpString[6] == 'i')
	{
    	uint8_t CounterStart = 8;
		uint8_t len = 0;

		printf("%s\n", tmpString);

		for(;;)
		{
			if(tmpString[CounterStart + len] == ';')
			{
				break;
			}
			else
			{
				len++;
			}
		}

		char* TmpNameWiFi = malloc(sizeof(char) * (len + 1));
		if(TmpNameWiFi == NULL) return BLE_ATT_ERR_INSUFFICIENT_RES;

		for(uint8_t CurentCounter = 0; CurentCounter < len; CurentCounter++)
		{
			TmpNameWiFi[CurentCounter] = tmpString[CounterStart + CurentCounter];
		}

		TmpNameWiFi[len] = 0;

		printf("DATA TmpNameWiFi - %s\n", TmpNameWiFi);

		uint8_t CounterStart2 = CounterStart + len + 1;
		uint8_t len2 = 0;

		for(;;)
		{
			if(tmpString[CounterStart2 + len2] == ';')
			{
				break;
			}
			else
			{
				len2++;
			}
		}

		char* TmpPasswordWiFi = malloc(sizeof(char) * (len2 + 1));
		if(TmpPasswordWiFi == NULL)
		{
			free(TmpNameWiFi);
			return BLE_ATT_ERR_INSUFFICIENT_RES;
		}

		for(uint8_t CurentCounter = 0; CurentCounter < len2; CurentCounter++)
		{
			TmpPasswordWiFi[CurentCounter] = tmpString[CounterStart2 + CurentCounter];
		}

		TmpPasswordWiFi[len2] = 0;

		printf("DATA TmpPasswordWiFi - %s\n", TmpPasswordWiFi);

		memset(pointerDataWiFiServer->WiFiName, '\0', sizeof pointerDataWiFiServer->WiFiName);
		memset(pointerDataWiFiServer->WiFiPass, '\0', sizeof pointerDataWiFiServer->WiFiPass);

		memcpy(pointerDataWiFiServer->WiFiName, TmpNameWiFi, len);
		memcpy(pointerDataWiFiServer->WiFiPass, TmpPasswordWiFi, len2);

		pointerSistemFlags->flagBLEToConnectWiFi = 1;
    	pointerSistemFlags->flagConnectBLE = 0;
    	pointerSistemFlags->flagOutBLEToDisp = 0;

    	WriteToNVSDataWiFi(pointerDataWiFiServer);

		free(TmpNameWiFi);
		free(TmpPasswordWiFi);
	}
    else if(tmpString[0] == 'w' && tmpString[1] == 'o' && tmpString[2] == 'r' && tmpString[3] == 'k')
    {
    	uint8_t CounterStart = 5;
		uint8_t len = 0;

		for(;;)
		{
			if(tmpString[CounterStart + len] == ';')
			{
				break;
			}
			else
			{
				len++;
			}
		}

		char TmpTimeHours[10];

		for(uint8_t CurentCounter = 0; CurentCounter < len; CurentCounter++)
		{
			TmpTimeHours[CurentCounter] = tmpString[CounterStart + CurentCounter];
		}

		TmpTimeHours[len] = 0;

		printf("DATA TmpTimeHours - %s\n", TmpTimeHours);

    	uint8_t CounterStart2 = CounterStart + len + 1;
		uint8_t len2 = 0;

		for(;;)
		{
			if(tmpString[CounterStart2 + len2] == ';')
			{
				break;
			}
			else
			{
				len2++;
			}
		}

		char TmpTimeMins[10];

		for(uint8_t CurentCounter = 0; CurentCounter < len2; CurentCounter++)
		{
			TmpTimeMins[CurentCounter] = tmpString[CounterStart2 + CurentCounter];
		}

		TmpTimeMins[len2] = 0;

		printf("DATA TmpTimeMins - %s\n", TmpTimeMins);

    	uint8_t CounterStart3 = CounterStart2 + len2 + 1;
		uint8_t len3 = 0;

		for(;;)
		{
			if(tmpString[CounterStart3 + len3] == ';')
			{
				break;
			}
			else
			{
				len3++;
			}
		}

		char TmpTemp[10];

		for(uint8_t CurentCounter = 0; CurentCounter < len3; CurentCounter++)
		{
			TmpTemp[CurentCounter] = tmpString[CounterStart3 + CurentCounter];
		}

		TmpTemp[len3] = 0;

		printf("DATA TmpTemp - %s\n", TmpTemp);

    	uint8_t CounterStart4 = CounterStart3 + len3 + 1;
		uint8_t len4 = 0;

		for(;;)
		{
			if(tmpString[CounterStart4 + len4] == ';')
			{
				break;
			}
			else
			{
				len4++;
			}
		}

		char TmpTypeProg[10];

		for(uint8_t CurentCounter = 0; CurentCounter < len4; CurentCounter++)
		{
			TmpTypeProg[CurentCounter] = tmpString[CounterStart4 + CurentCounter];
		}

		TmpTypeProg[len4] = 0;

		printf("DATA TmpTypeProg - %s\n", TmpTypeProg);

    	uint8_t CounterStart5 = CounterStart4 + len4 + 1;
		uint8_t len5 = 0;

		for(;;)
		{
			if(tmpString[CounterStart5 + len5] == ';')
			{
				break;
			}
			else
			{
				len5++;
			}
		}

		char TmpNameProg[10];

		for(uint8_t CurentCounter = 0; CurentCounter < len5; CurentCounter++)
		{
			TmpNameProg[CurentCounter] = tmpString[CounterStart5 + CurentCounter];
		}

		TmpNameProg[len5] = 0;

		printf("DATA len TmpNameProg - %d\n", strlen(TmpNameProg));
		printf("DATA TmpNameProg - %s\n", TmpNameProg);

		pointerSistemFlags->StartProg.Temp = atoi(TmpTemp);
		pointerSistemFlags->StartProg.TimeHour = atoi(TmpTimeHours);
		pointerSistemFlags->StartProg.TimeMinute = atoi(TmpTimeMins);
		pointerSistemFlags->StartProg.TypeProgram = atoi(TmpTypeProg);
		sprintf(pointerSistemFlags->StartProg.Name, "%s", TmpNameProg);

		pointerPositionGUI->NextPositionGUI = MenuProgWork;
    }
    else if(tmpString[0] == 's' && tmpString[1] == 't' && tmpString[2] == 'o' && tmpString[3] == 'p')
	{
    	pointerSistemFlags->flagProgCurrentMode = 5;
    	pointerSistemFlags->ReversTimeToEndMinute = 0;
    	pointerSistemFlags->ReversTimeToEndHour = 0;
    	pointerSistemFlags->flagUpdateTimeToDisp = 1;
	}
    else
    {

    }

    return 0;
}

// Read data from ESP32 defined as server
static int device_read(uint16_t con_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
	char DataBuff[250];
	sprintf(DataBuff, "{\"temperature\":\"%s\",\"settemperature\":\"%s\",\"status\":\"%s\",\"timeend\":\"%s\",\"settimeend\":\"%s\",\"load\":\"%s\",\"modeSmoke\":\"%c\",\"nameprog\":\"%s\",\"id\":\"%s\",\"firmware_version\":\"0.1.0\"}",
			pointerDataToSend->CurrentTemperature,
			pointerDataToSend->SetTemperature,
			pointerDataToSend->NameStatus[pointerDataToSend->NuberStatus],
			pointerDataToSend->SetTimeProg,
			pointerDataToSend->CurrentToEndTimeProg,
			pointerDataToSend->NameStatusRele[pointerDataToSend->NuberStatusRele],
			pointerDataToSend->NameTypeProgram[pointerDataToSend->NumberTypeProgram],
			pointerDataToSend->NameProg,
			pointerDataToSend->ID);
//	printf("Data to out - %s\n", DataBuff);
	os_mbuf_append(ctxt->om, DataBuff, strlen(DataBuff));
    return 0;
}

static int device_read_void(uint16_t con_handle, uint16_t attr_handle, struct ble_gatt_access_ctxt *ctxt, void *arg)
{
	printf("Data transmit void\n");
//    os_mbuf_append(ctxt->om, "{\"temperature\":\"28\",\"settemperature\":\"100\",\"status\":\"work\",\"timeend\":\"12:00\",\"settimeend\":\"12:30\",\"load\":\"0\",\"modeSmoke\":\"1\",\"nameprog\":\"Мясо\",\"id\":\"34865D4E5BE2", strlen("{\"temperature\":\"28\",\"settemperature\":\"100\",\"status\":\"work\",\"timeend\":\"12:00\",\"settimeend\":\"12:30\",\"load\":\"0\",\"modeSmoke\":\"1\",\"nameprog\":\"Мясо\",\"id\":\"34865D4E5BE2"));
    return 0;
}

// Array of pointers to other service definitions
// UUID - Universal Unique Identifier
static const struct ble_gatt_svc_def gatt_svcs[] =
{
	{
		.type = BLE_GATT_SVC_TYPE_PRIMARY,// @suppress("Symbol is not resolved")
		.uuid = &SERVICE_UUID.u,
		.characteristics = (struct ble_gatt_chr_def[])
		{
			{
				.uuid = &CHARACTERISTIC_UUID.u, // Define UUID for reading
				.flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY | BLE_GATT_CHR_F_INDICATE,// @suppress("Symbol is not resolved")
//				.access_cb = device_read_void
				.access_cb = device_read
			},
			{
				.uuid = &CHARACTERISTICstatus_UUID.u, // Define UUID for reading
				.flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY | BLE_GATT_CHR_F_INDICATE,// @suppress("Symbol is not resolved")
				.val_handle = &control_notif_handle,
				.access_cb = device_read,
			},
			{
				.uuid = &CHARACTERISTICheat_UUID.u, // Define UUID for reading
				.flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY | BLE_GATT_CHR_F_INDICATE,// @suppress("Symbol is not resolved")
				.access_cb = device_read
			},
			{
				.uuid = &CHARACTERISTICend_UUID.u, // Define UUID for reading
				.flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY | BLE_GATT_CHR_F_INDICATE,// @suppress("Symbol is not resolved")
				.access_cb = device_read
			},
			{
				.uuid = &CHARACTERISTICback_UUID.u, // Define UUID for writing
				.flags = BLE_GATT_CHR_F_WRITE,// @suppress("Symbol is not resolved")
				.access_cb = device_write
			},
			{
				0
			}
		}
	},
	{
		0
	}
};

// BLE event handling
static int ble_gap_event(struct ble_gap_event *event, void *arg)
{
	printf("Event gap %d\n", event->type);
    switch (event->type)
    {
    // Advertise if connected
    case BLE_GAP_EVENT_CONNECT:// @suppress("Symbol is not resolved")
        ESP_LOGI("GAP", "BLE GAP EVENT CONNECT %s", event->connect.status == 0 ? "OK!" : "FAILED!");
        if (event->connect.status != 0)
        {
            ble_app_advertise();
        }
        break;
    // Advertise again after completion of the event
    case BLE_GAP_EVENT_ADV_COMPLETE:// @suppress("Symbol is not resolved")
//        ESP_LOGI("GAP", "BLE GAP EVENT");
        ble_app_advertise();
        break;
    case BLE_GAP_EVENT_SUBSCRIBE:// @suppress("Symbol is not resolved")
//    	printf("BLE_GAP_EVENT_SUBSCRIBE\n");
    	pointerSistemFlags->flagConnectBLE = 1;
    	pointerSistemFlags->flagOutBLEToDisp = 0;
//    	printf("flag = %d\n", flag_connect_and_Notify);
    	break;
    case BLE_GAP_EVENT_NOTIFY_TX:// @suppress("Symbol is not resolved")
//    	printf("BLE_GAP_EVENT_NOTIFY_TX\n");
    	break;
    case BLE_GAP_EVENT_NOTIFY_RX:// @suppress("Symbol is not resolved")
//		printf("BLE_GAP_EVENT_NOTIFY_RX\n");
		break;
    case BLE_GAP_EVENT_DISCONNECT:
    	printf("Device BLE Disconnect\n");
    	pointerSistemFlags->flagConnectBLE = 0;
    	pointerSistemFlags->flagOutBLEToDisp = 0;
    	if(pointerSistemFlags->flagBLEToConnectWiFi == 0)
    	{
    		ble_app_advertise();
    	}
    	break;
    default:
        break;
    }
    return 0;
}

// Define the BLE connection
void ble_app_advertise(void)
{
    // GAP - device name definition
    struct ble_hs_adv_fields fields;
    const char *device_name;
    memset(&fields, 0, sizeof(fields));
    device_name = ble_svc_gap_device_name(); // Read the BLE device name
    fields.name = (uint8_t *)device_name;
    fields.name_len = strlen(device_name);
    fields.name_is_complete = 1;
    ble_gap_adv_set_fields(&fields);

    // GAP - device connectivity definition
    struct ble_gap_adv_params adv_params;
    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND; // connectable or non-connectable // @suppress("Symbol is not resolved")
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN; // discoverable or non-discoverable // @suppress("Symbol is not resolved")
    int rc = ble_gap_adv_start(ble_addr_type, NULL, BLE_HS_FOREVER, &adv_params, ble_gap_event, NULL);// @suppress("Symbol is not resolved")
    if(rc != 0)
    {
    	printf("BLE advertise start failed rc=%d\n", rc);
    }
}

// The application
 void ble_app_on_sync(void)
{
    ble_hs_id_infer_auto(0, &ble_addr_type); // Determines the best address type automatically
    ble_app_advertise(); // Define the BLE connection
}

// The infinite task
 static void host_task(void *param)
{
//	printf("host_task\n");
    nimble_port_run(); // This function will return only when nimble_port_stop() is executed
}

 void gatt_svr_register_cb(struct ble_gatt_register_ctxt *ctxt, void *arg)
 {
     char buf[BLE_UUID_STR_LEN];// @suppress("Symbol is not resolved")
//     printf("gatt_svr_register_cb ctxt = %d\n", ctxt->op);
 }

 void notify_over_control_chr(int16_t conn_handle, char* data)
 {
     struct os_mbuf *om;

     if(conn_handle > -1)
     {
         om = ble_hs_mbuf_from_flat(data, strlen(data));

//         ESP_LOGI("notify", "Notifying conn=%d", conn_handle);

         int rc = ble_gattc_notify_custom((uint16_t)conn_handle, control_notif_handle, om);

         if (rc != 0)
         {
//             ESP_LOGE("notify", "error notifying; rc=%d", rc);
             return;
         }
     }
 }

 void bleprph_on_reset(int reason)
{
    MODLOG_DFLT(ERROR, "Resetting state; reason=%d\n", reason);
}

void BLEenble(void)
{
	esp_bt_controller_enable(1);
}

void BLEdisable(void)
{
	esp_bt_controller_disable();
}

void InitBLE(struct _DataToSend *DataToSend, struct _DataWiFiServer *DataWiFiServer, struct _SistemFlags *SistemFlags, struct _PositionGUI * NumberGUI)
{
	pointerDataToSend = DataToSend;
	pointerDataWiFiServer = DataWiFiServer;
	pointerSistemFlags = SistemFlags;
	pointerPositionGUI = NumberGUI;

	pointerSistemFlags->flagBLEInit = 1;

	esp_nimble_hci_init();
	printf("BLE 1\n");
	nimble_port_init();
	printf("BLE 2\n");
	char tmpNameBLE[25];
	sprintf(tmpNameBLE, "MALINOVKA_%s", DataToSend->ID);
	ble_svc_gap_device_name_set(tmpNameBLE);
	printf("BLE 3\n");
	ble_svc_gap_init();
	printf("BLE 4\n");
	ble_svc_gatt_init();
	printf("BLE 41\n");
	ble_svc_ans_init();
	printf("BLE 5\n");
	ble_gatts_count_cfg(gatt_svcs); // 4 - Initialize NimBLE configuration - config gatt services
	printf("BLE 6\n");
	ble_gatts_add_svcs(gatt_svcs); // 4 - Initialize NimBLE configuration - queues gatt services.
	printf("BLE 7\n");
	ble_hs_cfg.sync_cb = ble_app_on_sync; // 5 - Initialize application
	printf("BLE 8\n");
	ble_hs_cfg.reset_cb = bleprph_on_reset;
	ble_hs_cfg.gatts_register_cb = gatt_svr_register_cb;
	printf("BLE 9\n");
	nimble_port_freertos_init(host_task); // 6 - Run the thread
	printf("BLE 0\n");
	esp_bt_controller_disable();
}
