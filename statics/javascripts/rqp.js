"use strict";

let whoami = $("#whoami");
let whoamiButton = $("#whoamiButton");
let resourcesName = $("#resourcesName");
let ResourceAccessButton = $("#ResourceAccessButton");
var modal = document.getElementById("myModal");
let qr_code = $("#qrcode");
var $el = jQuery("#qrcode");
// Get the <span> element that closes the modal
var span = document.getElementsByClassName("close")[0];

//document.getElementsByClassName("close")[0];

let logger = $("#logger");
let nowAccount = "";
let nowResource = "";

let password = `nccutest`;
let resourceIds = new Map();
let asURL = ""
let localIP = ""
let ticket = ""
// used mapping
//let IoTLoginedMap = new Map();
//let authorization_address = "";

//let addressPasswordMap = new Map();

function log(...inputs) {
  for (let input of inputs) {
    if (typeof input === "object") {
      input = JSON.stringify(input, null, 2);
    }
    logger.html(input + "\n" + logger.html());
  }
}

// 當按下登入按鍵時
whoamiButton.on("click", async function () {
  nowAccount = whoami.val();
  log(nowAccount, "Login Ethereum Account");
});

// 載入使用者至 select tag
$.get("/blockchain/accounts", function (accounts) {
  for (let account of accounts) {
    whoami.append(`<option value="${account}">${account}</option>`);
  }
  nowAccount = whoami.val();
  log(nowAccount, "Login Ethereum Account");
});

$.get("/umaRqP/getIP", function (ip) {
  localIP = ip;
  log(`ip${localIP}"`);
});

// 載入存在的resource至 select tag
$.get("/umaRqP/getExistResources", function (results) {
  for (let info of results.info) {
    resourcesName.append(
      `<option value="${info.resourceName}">${info.resourceName}</option>`
    );
    resourceIds[info.resourceName] = info.resourceDID;
  }
  nowResource = resourcesName.val();
  log(`Choosed resource:${nowResource}`);
});

ResourceAccessButton.on("click", function () {
  //先檢查resource id有沒有紀錄值
  let resource_name = resourcesName.val();
  if (resourceIds[resource_name] == null) {
    log(`resource ID empty`);
    alert(`resource ID empty`);
    return;
  }
  //log(`resourceId:${resourceIds[resource_name]}`);

  waitTransactionStatus();

  $.post(
    "uma/requestRegister",
    {
      account: nowAccount,
      password: password,
      didMethod: `ethr`,
      resourceIdentity: resourceIds[resource_name]
    },
    function (result) {
      if (result.status === true) {
        doneTransactionStatus();
        asURL = result.asURL;
        ticket = result.ticket;
        //first clean the div cotent
        //then append the new qrcode
        // have to get local host ip
        qr_code.html("").qrcode({
          width: 250, //寬
          height: 250, //高
          render: "div",
          background: "#FFFFFF", //背景色
          foreground: "#1C3454", //前景色
          text: `http://${localIP}:3001/login.html?ticket=${ticket}&asURL=${asURL}`
        });
        modal.style.display = "block";
        log(`http://${localIP}:3001/login.html?ticket=${ticket}&asURL=${asURL}`);
      } else {
        log(`update failed`);
        log(result);
        doneTransactionStatus();
        alert(`request access failed`);
      }
    }
  );
});

// pop up box
// 當按下登入按鍵時
// When the user clicks on <span> (x), close the modal
span.onclick = function () {
  modal.style.display = "none";
};

// When the user clicks anywhere outside of the modal, close it
window.onclick = function (event) {
  if (event.target == modal) {
    modal.style.display = "none";
  }
};

//deploy tr
function waitTransactionStatus() {
  $("#accountStatus").html(
    'Account status:<b style="color: blue">(Transaction Padding...)</b>'
  );
}

function doneTransactionStatus() {
  $("#accountStatus").text("Account status:");
}

//button style setting
$(":button").each(function () {
  $(this).on({
    mouseover: function () {
      $(this).attr("style", "background-color: #608de2");
    },
    mouseout: function () {
      $(this).attr("style", "background-color: #4364a1");
    }
  });
});
