#include <Pozyx.h>
#include <Pozyx_definitions.h>
#include <Ciao.h>

#define LED_POWER 1
#define LED_RUNNING 2
#define LED_RANGING 4

bool isRanging = false;
String serverAddress = "";

// Commands from ios-device
const char BEGIN_RANGING = 'r';
const char STOP_RANGING = 's';
const char CALIBRATE = 'c';

// Array of Anchor IDs holding up to 10 values
uint16_t anchors[10];

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
// Solution for derotating quaternion from
// https://github.com/pozyxLabs/Pozyx-processing/blob/master/examples/pozyx_orientation3D/pozyx_orientation3D.pde
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
  // Initialize Pozyx
  if (!Pozyx.begin(false, MODE_INTERRUPT, POZYX_INT_MASK_RX_DATA, 0)) {
    abort();
  }

  // Revoke Pozyx system's control over all LEDs
  Pozyx.setLedConfig(0x0);
  // Set Power LED to indicate system is running. Not active though
  Pozyx.setLed(LED_POWER, true);

  // Initialize Ciao
  Ciao.begin();

  // Turn on LED1 to indicate the sketch is running successfully
  Pozyx.setLed(LED_RUNNING, true);
}

void loop() {
  // Read Ciao Restserver to check for messages from iOS-device
  readRestServer();

  // Perform measurements and send data to iOS-device
  if (isRanging) {
    sendRangingData();
  }
}

void readRestServer() {
  // Read Ciao Restserver
  CiaoData data = Ciao.read("restserver");
  if (!data.isEmpty()) {
    String messageID = data.get(0);
    String message = data.get(2);

    // Check which command has been sent
    String command[2];
    Ciao.splitString(message, "/", command, 2);
    char task = *command[0].begin();

    switch (task) {
      case BEGIN_RANGING: {
        // Get IP address of iOS-device from message and save it for later
        serverAddress = command[1];
        // Initiate ranging process
        isRanging = true;
        // Indicate ranging is active by setting LED accordingly
        Pozyx.setLed(LED_RANGING, true);
        // Send an ACK as response to iOS-device
        Ciao.writeResponse("restserver", messageID, "ACK");
        break;
      }
      
      case STOP_RANGING: {
        // Cancel ranging process
        isRanging = false;
        // Turn off LED
        Pozyx.setLed(LED_RANGING, false);
        // Send an ACK as response to iOS-device
        Ciao.writeResponse("restserver", messageID, "ACK");
        break;
      }
      
      case CALIBRATE: {
        // Cancel ranging process
        isRanging = false;
        // Turn off LED
        Pozyx.setLed(LED_RANGING, false);

        // Clear pozyx device list
        Pozyx.clearDevices();
        numAnchors = 0;

        // Array anchorData has to have space for up to 10 anchors with 3 values for each
        String anchorData[30] = {};
        // Get anchorData from message
        Ciao.splitString(command[1], "&", anchorData, 30);

        device_coordinates_t device;

        for (int i = 0; i < 10; i++) {
          // Check if there is a value for a new anchor
          if (anchorData[3 * i] == "-1") {
            break;
          }

          // Parse anchorData
          String anchorDataComponent[2];

          Ciao.splitString(anchorData[3 * i], "=", anchorDataComponent, 2);
          device.network_id = (uint16_t)anchorDataComponent[1].toInt();
          
          Ciao.splitString(anchorData[3 * i + 1], "=", anchorDataComponent, 2);
          device.pos.x = (uint32_t)anchorDataComponent[1].toInt();
          
          Ciao.splitString(anchorData[3 * i + 2], "=", anchorDataComponent, 2);
          device.pos.y = (uint32_t)anchorDataComponent[1].toInt();

          // Mark as anchor
          device.flag = 0x1;
          // Set height to 1m as 3D positioning is not used
          device.pos.z = 1000;
          // Add anchor to device list
          Pozyx.addDevice(device);
          anchors[numAnchors] = device.network_id;
          numAnchors++;
        }
        
        // Measure distances to all anchors and send data to iOS-device
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
  // Get acceleration in global coordinates
  float32_t acceleration[3];
  getAccel_quat(acceleration);
  
//  // Get acceleration in body coordinates. Uncomment this if conversion to global coordinates is not working properly
//  acceleration_t acceleration;
//  Pozyx.getAcceleration_mg(&acceleration);
//  acceleration[0]=acceleration.x;
//  acceleration[1]=acceleration.y;

  String message = "";
  // Measure distances to all anchors
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
  
  // Send measurement data to ios-device
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
    // Send calibrated position
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

    // Send initial distance measurement
    Pozyx.doRanging(anchors[i], &range);
    calibrationMessage += "&dist";
    calibrationMessage += i;
    calibrationMessage += "=";
    calibrationMessage += range.distance;
    
    if (i != numAnchors - 1) {
      calibrationMessage += "&";
    }
  }

  // Send calibration data to ios-device
  Ciao.writeResponse("restserver", messageID, calibrationMessage);
}
