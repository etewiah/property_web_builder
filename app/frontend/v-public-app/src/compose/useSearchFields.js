export default function () {
  function getSearchFields(saleOrRental) {
    // debugger
    // will eventually get this from the server
    let priceFromFieldName = "forSalePriceFrom"
    let priceTillFieldName = "forSalePriceTill"
    if (saleOrRental === "rental") {
      priceTillFieldName = "forRentPriceTill"
    }
    if (saleOrRental === "rental") {
      priceFromFieldName = "forRentPriceFrom"
    }
    return [
      {
        "toggleOnMobile": false,
        "labelTextTKey": "client_shared.fieldLabels.priceFrom",
        "classNames": "xs12 sm4 lg3",
        "tooltipTextTKey": "",
        "fieldName": priceFromFieldName,
        "queryStringName": "price_min",
        "inputType": "priceText",
        "defaultValueForAlert": "50000",
        "defaultValueForSearch": "50000",
        "sortOrder": 3,
        "currencyPrefix": "€",
        "optionsValues": [
          "25,000",
          "50,000",
          "100,000",
          "250,000",
          "500,000",
          "1,000,000",
          "2,500,000",
          "5,000,000",
          "10,000,000",
          "25,000,000"
        ]
      },
      {
        "toggleOnMobile": true,
        "labelTextTKey": "client_shared.fieldLabels.priceTill",
        "classNames": "xs12 sm4 lg3",
        "tooltipTextTKey": "",
        "fieldName": priceTillFieldName,
        "queryStringName": "price_max",
        "inputType": "priceText",
        "defaultValueForAlert": "5000000",
        "defaultValueForSearch": "10000000",
        "sortOrder": 4,
        "currencyPrefix": "€",
        "optionsValues": [
          "50,000",
          "100,000",
          "250,000",
          "500,000",
          "1,000,000",
          "2,500,000",
          "5,000,000",
          "10,000,000",
          "25,000,000",
          "50,000,000"
        ]
      },
      {
        "toggleOnMobile": true,
        "labelTextTKey": "client_shared.fieldLabels.minBedrooms",
        "classNames": "xs12 sm4 lg3",
        "tooltipTextTKey": "",
        "fieldName": "bedroomsFrom",
        "queryStringName": "bedrooms_min",
        "defaultValueForSearch": "0",
        "defaultValueForAlert": "2",
        "inputType": "counter",
        "sortOrder": 8,
        "optionsValues": [
          "0",
          "1",
          "2",
          "3",
          "4",
          "5",
          "6",
          "7",
          "8",
          "9",
          "10",
          "11",
          "12",
          "13",
          "14",
          "15",
          "16",
          "17",
          "18",
          "19",
          "20",
        ]
      },
      {
        "toggleOnMobile": true,
        "labelTextTKey": "client_shared.fieldLabels.minBathrooms",
        "classNames": "xs12 sm4 lg3",
        "tooltipTextTKey": "",
        "fieldName": "bathroomsFrom",
        "queryStringName": "bathrooms_min",
        "defaultValueForSearch": "0",
        "defaultValueForAlert": "1",
        "inputType": "counter",
        "sortOrder": 9,
        "optionsValues": [
          "0",
          "1",
          "2",
          "3",
          "4",
          "5",
          "6",
          "7",
          "8",
          "9",
          "10",
          "11",
          "12",
          "13",
          "14",
          "15",
          "16",
          "17",
          "18",
          "19",
          "20",
        ]
      }
    ]
  }
  return {
    getSearchFields
  }
}