#include "initWiFi.h"

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

#define EXAMPLE_ESP_MAXIMUM_RETRY  5

//#define EXAMPLE_URL            				"http://62.173.145.45:9999/device/link/MALINOVKA_34865D4E5BE2"
#define EXAMPLE_PING_COUNT         		10000
#define EXAMPLE_PING_INTERVAL      		1

#define MAX_HTTP_OUTPUT_BUFFER 256

static EventGroupHandle_t s_wifi_event_group;

static int s_retry_num = 0;

struct _DataToSend *pointerDataToSendW;
struct _DataWiFiServer *pointerDataWiFiServerW;
struct _SistemFlags *pointerSistemFlagsW;
struct _PositionGUI *pointerPositionGUIW;

static uint8_t extract_json_string(const char *json, const char *key, char *out, uint16_t out_size)
{
	char pattern[32];
	snprintf(pattern, sizeof(pattern), "\"%s\":\"", key);
	char *start = strstr(json, pattern);
	if(start == NULL) return 0;
	start += strlen(pattern);
	char *end = strchr(start, '"');
	if(end == NULL) return 0;
	uint16_t len = end - start;
	if(len >= out_size) len = out_size - 1;
	memcpy(out, start, len);
	out[len] = 0;
	return 1;
}

static void start_ota_update(const char *url)
{
	printf("OTA update url: %s\n", url);
	esp_http_client_config_t http_config = {
		.url = url,
		.timeout_ms = 30000,
		.keep_alive_enable = true,
	};
	esp_https_ota_config_t ota_config = {
		.http_config = &http_config,
	};
	esp_err_t ret = esp_https_ota(&ota_config);
	if(ret == ESP_OK)
	{
		printf("OTA update complete, restarting\n");
		esp_restart();
	}
	else
	{
		printf("OTA update failed: %d\n", ret);
	}
}

esp_err_t _http_event_handler(esp_http_client_event_t *evt)
{
	char output_buffer[250];  // Buffer to store response of http request from event handler
//	static int output_len;       // Stores number of bytes read

//	printf("Event http get %d\n", evt->event_id);

//	printf("HTTP_EVEEN number - %d\n", evt->event_id);

	switch(evt->event_id)
	{
	case HTTP_EVENT_ON_DATA:
		printf("HTTP_EVENT_ON_DATA, len=%d\n", evt->data_len);
		if(evt->data_len > 249) return 0;
		memcpy(output_buffer, evt->data, evt->data_len);
		output_buffer[evt->data_len] = 0x00;
		printf("Data local buf %s\n", output_buffer);
		uint8_t totalCounter = 0;

		uint8_t tmpMode = 0;
		uint8_t tmpTemp = 0;
		uint8_t tmpHour = 0;
		uint8_t tmpMinute = 0;
		char tmpName[40];

		if(strstr(output_buffer, "\"status\":\"ota\"") != NULL)
		{
			char ota_url[180];
			if(extract_json_string(output_buffer, "url", ota_url, sizeof(ota_url)))
			{
				start_ota_update(ota_url);
			}
		}
		else if(output_buffer[0] == '{' &&  output_buffer[1] == '"' && output_buffer[2] == 's' && output_buffer[3] == 't' && output_buffer[4] == 'a' && output_buffer[5] == 't' && output_buffer[6] == 'u' && output_buffer[7] == 's' && output_buffer[8] == '"' && output_buffer[9] == ':' && output_buffer[10] == '"' && output_buffer[11] == 'w' && 	output_buffer[12] == 'o' && 	output_buffer[13] == 'r' && 	output_buffer[14] == 'k' && 	output_buffer[15] == '"')
		{
			totalCounter = 16;

			for(;;)
			{
				if(output_buffer[totalCounter] == ':')
				{
					totalCounter++;
					tmpMode = output_buffer[totalCounter] - 48;
					break;
				}
				else
				{
					totalCounter++;
				}
			}

			for(;;)
			{
				if(output_buffer[totalCounter] == ':')
				{
					totalCounter++;
					uint8_t localCounter = totalCounter;
					char tmp[4] = "000";

					for(;;)
					{
						if(output_buffer[localCounter] == ',')
						{
							for(uint8_t i = 0; totalCounter < localCounter; totalCounter++)
							{
								tmp[i] = output_buffer[totalCounter];
								i++;
								if(totalCounter + 1 == localCounter) tmp[i] = 0;
							}
							break;
						}
						else
						{
							localCounter++;
						}
					}

					tmpTemp = atoi(tmp);
					break;
				}
				else
				{
					totalCounter++;
				}
			}

			for(;;)
			{
				if(output_buffer[totalCounter] == ':')
				{
					totalCounter++;
					uint8_t localCounter = totalCounter;
					char tmp[4] = "000";

					for(;;)
					{
						if(output_buffer[localCounter] == ',')
						{
							for(uint8_t i = 0; totalCounter < localCounter; totalCounter++)
							{
								tmp[i] = output_buffer[totalCounter];
								i++;
								if(totalCounter + 1 == localCounter) tmp[i] = 0;
							}
							break;
						}
						else
						{
							localCounter++;
						}
					}

					tmpHour = atoi(tmp);
					break;
				}
				else
				{
					totalCounter++;
				}
			}

			for(;;)
			{
				if(output_buffer[totalCounter] == ':')
				{
					totalCounter++;
					uint8_t localCounter = totalCounter;
					char tmp[4] = "000";

					for(;;)
					{
						if(output_buffer[localCounter] == ',')
						{
							for(uint8_t i = 0; totalCounter < localCounter; totalCounter++)
							{
								tmp[i] = output_buffer[totalCounter];
								i++;
								if(totalCounter + 1 == localCounter) tmp[i] = 0;
							}
							break;
						}
						else
						{
							localCounter++;
						}
					}

					tmpMinute = atoi(tmp);
					break;
				}
				else
				{
					totalCounter++;
				}
			}

			for(;;)
			{
				if(output_buffer[totalCounter] == ':')
				{
					totalCounter+=2;
					uint8_t localCounter = totalCounter;
					char tmp[40];

					for(;;)
					{
						if(output_buffer[localCounter] == '"')
						{
							for(uint8_t i = 0; totalCounter < localCounter; totalCounter++)
							{
								tmp[i] = output_buffer[totalCounter];
								i++;
								if(totalCounter + 1 == localCounter) tmp[i] = 0;
							}
							break;
						}
						else
						{
							localCounter++;
						}
					}

					sprintf(tmpName, "%s", tmp);
					break;
				}
				else
				{
					totalCounter++;
				}
			}

			printf("tmpMode - %d\ntmpTemp - %d\ntmpHour - %d\ntmpMinute - %d\ntmpName - %s\n", tmpMode, tmpTemp, tmpHour, tmpMinute, tmpName);

			pointerSistemFlagsW->StartProg.Temp = tmpTemp;
			pointerSistemFlagsW->StartProg.TimeHour = tmpHour;
			pointerSistemFlagsW->StartProg.TimeMinute = tmpMinute;
			pointerSistemFlagsW->StartProg.TypeProgram = tmpMode;
			sprintf(pointerSistemFlagsW->StartProg.Name, "%s", tmpName);
			pointerPositionGUIW->NextPositionGUI = MenuProgWork;
		}
		else if(output_buffer[0] == '{' &&  output_buffer[1] == '"' && output_buffer[2] == 's' && output_buffer[3] == 't' && output_buffer[4] == 'a' && output_buffer[5] == 't' && output_buffer[6] == 'u' && output_buffer[7] == 's' && output_buffer[8] == '"' && output_buffer[9] == ':' && output_buffer[10] == '"' && output_buffer[11] == 's' && 	output_buffer[12] == 't' && 	output_buffer[13] == 'o' && 	output_buffer[14] == 'p' && 	output_buffer[15] == '"')
		{
			pointerSistemFlagsW->flagProgCurrentMode = 5;
			pointerSistemFlagsW->ReversTimeToEndMinute = 0;
			pointerSistemFlagsW->ReversTimeToEndHour = 0;
			pointerSistemFlagsW->flagUpdateTimeToDisp = 1;
		}
		break;
	case HTTP_EVENT_DISCONNECTED:
//		esp_wifi_stop();
//        pointerSistemFlagsW->flagConnectWiFi = 0;
//        pointerSistemFlagsW->flagOutWiFiToDisp = 0;
//        pointerSistemFlagsW->flagWiFiDisconnectHotspot = 1;
		break;
	default:
		break;
	}

	return ESP_OK; // @suppress("Symbol is not resolved")
}

void TestConnectToServer(struct _DataWiFiServer * DataWiFiServer)
{
	if(strlen(DataWiFiServer->WayToServer) > 3)
	{
		esp_http_client_config_t configHTTP = {
				.url = DataWiFiServer->WayToServer,
				.method = HTTP_METHOD_POST,
				.event_handler = _http_event_handler,
				.disable_auto_redirect = true, // @suppress("Symbol is not resolved")
		};

		esp_http_client_handle_t client = esp_http_client_init(&configHTTP);

		char DataBuff[250];
		sprintf(DataBuff, "{\"temperature\":\"%s\",\"settemperature\":\"%s\",\"status\":\"%s\",\"timeend\":\"%s\",\"settimeend\":\"%s\",\"load\":\"%s\",\"modeSmoke\":\"%c\",\"nameprog\":\"%s\",\"firmware_version\":\"0.1.0\"}",
				pointerDataToSendW->CurrentTemperature,
				pointerDataToSendW->SetTemperature,
				pointerDataToSendW->NameStatus[pointerDataToSendW->NuberStatus],
				pointerDataToSendW->SetTimeProg,
				pointerDataToSendW->CurrentToEndTimeProg,
				pointerDataToSendW->NameStatusRele[pointerDataToSendW->NuberStatusRele],
				pointerDataToSendW->NameTypeProgram[pointerDataToSendW->NumberTypeProgram],
				pointerDataToSendW->NameProg);

		printf("DataBuff WiFi - %s\n", DataBuff);

		esp_http_client_set_header(client, "Content-Type", "application/json");
		esp_http_client_set_post_field(client, DataBuff, strlen(DataBuff));

		esp_http_client_perform(client);

		esp_http_client_get_status_code(client);
		esp_http_client_get_content_length(client);

		esp_http_client_cleanup(client);
	}
}

static void event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
	printf("Even wifi - %d\n", (uint8_t)event_id);

	  if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START)
	  {
	      esp_wifi_connect();
	  }
	  else if(event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_CONNECTED)
	  {
		  pointerSistemFlagsW->flagConnectWiFi = 1;
		  pointerSistemFlagsW->flagOutWiFiToDisp = 0;
		  printf("Popal sudo\n");
	  }
	  else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED)
	  {
	    if (s_retry_num < EXAMPLE_ESP_MAXIMUM_RETRY)
	    {
	        esp_wifi_connect();
	        s_retry_num++;
	        printf("retry to connect to the AP\n");
	    }
	    else
	    {
	    	vTaskDelay(1000 / portTICK_PERIOD_MS);
	        xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT); // @suppress("Symbol is not resolved")
	        pointerSistemFlagsW->flagConnectWiFi = 0;
	        pointerSistemFlagsW->flagOutWiFiToDisp = 0;
	        pointerSistemFlagsW->flagWiFiDisconnectHotspot = 1;
//	        esp_restart();
	    }
	    printf("connect to the AP fail\n");
	  }
	  else if(event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_STOP)
	  {
		vTaskDelay(1000 / portTICK_PERIOD_MS);
		xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT); // @suppress("Symbol is not resolved")
		pointerSistemFlagsW->flagConnectWiFi = 0;
		pointerSistemFlagsW->flagOutWiFiToDisp = 0;
		if(pointerSistemFlagsW->flagWiFiDisconnectHotspot == 0) pointerSistemFlagsW->flagWiFiDisconnectHotspot = 1;
	  }
	  else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP)
	  {
	    ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
	    printf("got ip:" IPSTR, IP2STR(&event->ip_info.ip));
	    printf("\n");
	    s_retry_num = 0;
	    xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT); // @suppress("Symbol is not resolved")
	  }
}

void wifi_init_sta(struct _DataToSend *DataToSend, struct _DataWiFiServer *DataWiFiServer, struct _SistemFlags *SistemFlags, struct _PositionGUI * NumberGUI)
{
	pointerDataToSendW = DataToSend;
	pointerDataWiFiServerW = DataWiFiServer;
	pointerSistemFlagsW = SistemFlags;
	pointerPositionGUIW = NumberGUI;

	printf("pointerDataWiFiServerW->WiFiName - %s\n", pointerDataWiFiServerW->WiFiName);
	printf("pointerDataWiFiServerW->WiFiPass - %s\n", pointerDataWiFiServerW->WiFiPass);
	printf("pointerDataWiFiServerW->WayToServer - %s\n", pointerDataWiFiServerW->WayToServer);

	s_wifi_event_group = xEventGroupCreate();
	printf("wifi 1 ---\n");

	esp_netif_init();
	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 2 ---\n");

	esp_event_loop_create_default();
	vTaskDelay(300 / portTICK_PERIOD_MS);
	printf("wifi 3 ---\n");

	esp_netif_create_default_wifi_sta();
	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 4 ---\n");

	wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();

	esp_wifi_init(&cfg);
	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 5 ---\n");

	esp_event_handler_instance_t instance_any_id;
	esp_event_handler_instance_t instance_got_ip;

	esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &event_handler, NULL, &instance_any_id); // @suppress("Symbol is not resolved")

	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 6 ---\n");

	esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &event_handler, NULL, &instance_got_ip); // @suppress("Symbol is not resolved")

	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 7 ---\n");

	wifi_config_t wifi_config = {
		.sta = {
			.threshold.authmode = WIFI_AUTH_WPA2_PSK,
			.pmf_cfg = {
				.capable = true, // @suppress("Symbol is not resolved")
				.required = false // @suppress("Symbol is not resolved")
			},
		},
	};

	memcpy(wifi_config.sta.ssid, pointerDataWiFiServerW->WiFiName, sizeof(pointerDataWiFiServerW->WiFiName));
	memcpy(wifi_config.sta.password, pointerDataWiFiServerW->WiFiPass, sizeof(pointerDataWiFiServerW->WiFiPass));

	esp_wifi_set_mode(WIFI_MODE_STA);
	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 8 ---\n");

	esp_wifi_set_ps(WIFI_PS_NONE);
	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 9 ---\n");

	esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
	vTaskDelay(100 / portTICK_PERIOD_MS);
	printf("wifi 10 ---\n");

	esp_wifi_start();
	printf("wifi 11 ---\n");

	printf("wifi_init_sta finished\n");

	EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT, pdFALSE, pdFALSE, portMAX_DELAY); // @suppress("Symbol is not resolved")

	pointerSistemFlagsW->FlagWifiInit = 1;

//	esp_event_handler_instance_unregister(IP_EVENT, IP_EVENT_STA_GOT_IP, instance_got_ip);
//	esp_event_handler_instance_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, instance_any_id); // @suppress("Symbol is not resolved")
//	vEventGroupDelete(s_wifi_event_group);
}

void WiFiStop()
{
	esp_wifi_stop();
}

void WiFiDeinit()
{
	esp_wifi_deinit();
}

void WiFiStart()
{
	esp_wifi_start();
	esp_wifi_connect();
}

void GetMACAddr(char tmpMac[13])
{
	uint8_t mac[6];

	esp_read_mac(mac, ESP_MAC_BT);

	sprintf(tmpMac, "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
//	printf("MAC ADDRES test - %s\n", tmpMac);
}

