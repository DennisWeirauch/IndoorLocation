#include <Pozyx.h>
#include <Pozyx_definitions.h>
#include <Ciao.h>

#define LED_POWER 1
#define LED_RUNNING 2
#define LED_RANGING 4

bool isRanging = false;
String serverAddress = "";

const char BEGIN_RANGING = 'r';
const char STOP_RANGING = 's';
const char CALIBRATE = 'c';

unsigned long lastMeasurementTime;

// Array of Anchor IDs holding up to 20 values
uint16_t anchors[20];

// Number of anchors in device list
uint8_t numAnchors;

// Sorts anchors by name so that later on only ranges have to be transfered without anchor
// name (the convention shall hold that only sorted range-arrays are being sent).
// The classic bubblesort algorithm is implemented.
void sort(uint16_t a[], uint8_t siz) {
  for (int i = 0; i < (siz - 1); i++) {
    for (int o = 0; o < (siz - (i + 1)); o++) {
      if (a[o] > a[o + 1]) {
        uint16_t temp = a[o];
        a[o] = a[o + 1];
        a[o + 1] = temp;
      }
    }
  }
}

// Transfers linear acceleration to global acceleration values by the use of quaternions.
// Faster and more accurate than calculation by Euler Angles. Maybe due to internal structure of Pozyx device.
void getAccel_quat(float32_t *worldAcc) {
  quaternion_t quat;
  linear_acceleration_t acceleration;
  Pozyx.getQuaternion(&quat);
  Pozyx.getLinearAcceleration_mg(&acceleration);

  float q00 = 2.0f * quat.x * quat.x;
  float q11 = 2.0f * quat.y * quat.y;
  float q22 = 2.0f * quat.z * quat.z;

  float q01 = 2.0f * quat.x * quat.y;
  float q02 = 2.0f * quat.x * quat.z;
  float q03 = 2.0f * quat.x * quat.weight;

  float q12 = 2.0f * quat.y * quat.z;
  float q13 = 2.0f * quat.y * quat.weight;

  float q23 = 2.0f * quat.z * quat.weight;

  worldAcc[0] = ((1.0f - q11 - q22) * acceleration.x + (q01 - q23) * acceleration.y + (q02 + q13) * acceleration.z);
  worldAcc[1] = ((q01 + q23) * acceleration.x + (1.0f - q00 - q22) * acceleration.y + (q12 - q03) * acceleration.z);
  worldAcc[2] = ((q02 - q13) * acceleration.x + (q12 + q03) * acceleration.y + (1.0f - q00 - q11) * acceleration.z);
}

void setup() {
  Serial.begin(115200);
  Serial.println("Starting Pozyx2iPhone...");
  // Initialize Pozyx
  if (!Pozyx.begin(false, MODE_INTERRUPT, POZYX_INT_MASK_RX_DATA, 0)) {
    abort();
  }

  // Revoke Pozyx system's control over all LEDs
  Pozyx.setLedConfig(0x0);
  Pozyx.setLed(LED_POWER, true);
  
  Ciao.begin();

  // Turn on LED1 to indicate the sketch is running successfully
  Pozyx.setLed(LED_RUNNING, true);

  lastMeasurementTime = millis();
  Serial.println("Pozyx2iPhone running...");
}

void loop() {
  readRestServer();

  if (isRanging) {
    // Make sure measurements are made every 200ms
    unsigned long currentTime = millis();
    unsigned long timeDiff = currentTime - lastMeasurementTime;
    if (timeDiff < 200) {
      delay(200 - timeDiff);
    }
    sendRangingData();
    lastMeasurementTime = currentTime;
  }
}

void readRestServer() {
  CiaoData data = Ciao.read("restserver");
  if (!data.isEmpty()) {
    String messageID = data.get(0);
    String message = data.get(2);

    String command[2];
    Ciao.splitString(message, "/", command, 2);
    char task = *command[0].begin();

    switch (task) {
      case BEGIN_RANGING: {
        serverAddress = command[1];
        isRanging = true;
        Pozyx.setLed(LED_RANGING, true);
        Ciao.writeResponse("restserver", messageID, "ACK");
        break;
      }
      
      case STOP_RANGING: {
        isRanging = false;
        Pozyx.setLed(LED_RANGING, false);
        Ciao.writeResponse("restserver", messageID, "ACK");
        break;
      }
      
      case CALIBRATE: {
        Pozyx.clearDevices();
        numAnchors = 0;

        // Array anchorData has to have space for up to 20 anchors with 3 values for each
        String anchorData[60] = {};
        Ciao.splitString(command[1], "&", anchorData, 60);

        device_coordinates_t device;

        for (int i = 0; i < 20; i++) {
          // Check if there is a value for a new anchor
          if (anchorData[3 * i] == "-1") {
            break;
          }

          String anchorDataComponent[2];

          Ciao.splitString(anchorData[3 * i], "=", anchorDataComponent, 2);
          device.network_id = (uint16_t)anchorDataComponent[1].toInt();
          
          Ciao.splitString(anchorData[3 * i + 1], "=", anchorDataComponent, 2);
          device.pos.x = (uint32_t)anchorDataComponent[1].toInt();
          
          Ciao.splitString(anchorData[3 * i + 2], "=", anchorDataComponent, 2);
          device.pos.y = (uint32_t)anchorDataComponent[1].toInt();
          
          device.flag = 0x1;
          device.pos.z = 1000;
          Pozyx.addDevice(device);
          anchors[numAnchors] = device.network_id;
          numAnchors++;
        }
        
        sendCalibrationData(messageID);
        break;
      }
      
      default: {
        break;
      }
    }
  }
}

void sendRangingData() {
  float32_t acceleration[3];
  getAccel_quat(acceleration);

  String message = "";
  for (int i = 0; i < numAnchors; i++) {
    device_range_t range;
    if (Pozyx.doRanging(anchors[i], &range) == POZYX_SUCCESS) {
      message += "dist";
      message += anchors[i];
      message += "=";
      message += range.distance;
      message += "&";
    }
  }
  message += "xAcc=";
  message += acceleration[0];
  message += "&yAcc=";
  message += acceleration[1];

  Ciao.write("rest", serverAddress, message, "POST");
}

void sendCalibrationData(String messageID) {
  // Sort obtained anchors
  sort(anchors, numAnchors);
  // Send Anchor Data to iPhone
  // Format: ID0=id0&xPos0=x0&yPos0=y0&dist0=d0&ID1=id1&...&IDN=idN&xPosN=xN&yPosN=yN&distN=dN
  String calibrationMessage = "";

  device_range_t range;
  coordinates_t coordinates;
  for (int i = 0; i < numAnchors; i++) {
    Pozyx.getDeviceCoordinates(anchors[i], &coordinates);
    calibrationMessage += "ID";
    calibrationMessage += i;
    calibrationMessage += "=";
    calibrationMessage += anchors[i];
    calibrationMessage += "&xPos";
    calibrationMessage += i;
    calibrationMessage += "=";
    calibrationMessage += coordinates.x;
    calibrationMessage += "&yPos";
    calibrationMessage += i;
    calibrationMessage += "=";
    calibrationMessage += coordinates.y;

    Pozyx.doRanging(anchors[i], &range);
    calibrationMessage += "&dist";
    calibrationMessage += i;
    calibrationMessage += "=";
    calibrationMessage += range.distance;
    
    if (i != numAnchors - 1) {
      calibrationMessage += "&";
    }
  }

  Ciao.writeResponse("restserver", messageID, calibrationMessage);
}

void sendErrorMessage(String messageID, String errorMessage) {
  errorMessage = "Pozyx Error: " + errorMessage;
  Ciao.writeResponse("restserver", messageID, errorMessage);
}

