let axios = require("axios")
const fs = require('fs')

const storeData = (data, path) => {
  try {
    fs.writeFileSync(path, JSON.stringify(data))
  } catch (err) {
    console.error(err)
  }
}

// https://apilist.tronscan.org/api/tokenholders?sort=-balance&limit=20&start=0&count=true&address=TCGTP5j9TSB1y6bt9Z3gJKCxwudYY1xCX5

async function main() {
    let start = 0;
    let total = 20;
    let result = [];
    while(start <= total){
        let res = await axios.get("https://apilist.tronscan.org/api/tokenholders?sort=-balance&limit=20&start=" +  start  + "&count=true&address=TCGTP5j9TSB1y6bt9Z3gJKCxwudYY1xCX5")
        total = res.data.total
        data =  res.data.data
        for(let i =0 ; i< data.length ; i++) {
            result.push(data[i])
        }
        start += 20
    }
    storeData(result, './result.json')
}

main()