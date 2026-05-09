import walker from 'folder-walker'
import fs from 'fs'
import verovio from 'verovio'

const verovioOptions = {
   "scale": 10,
   "pageWidth": 1500,
   "adjustPageHeight": true,
   "adjustPageWidth": true,
   "footer": "none",
   "header":"none",
   "openControlEvents": true,
   "outputFormatRaw": true,
   "removeIds": true,
   "svgFormatRaw": true,
   "svgHtml5": true,
   "svgRemoveXlink": true,
   "svgViewBox": true
}

/* Wait for verovio to load */
verovio.module.onRuntimeInitialized = () => {
  
  const tk = new verovio.toolkit()
  console.log('Using Verovio toolkit version: ' + tk.getVersion())

  let stream = walker(['music-encoding/build/assets/images/GeneratedImages'])

  let processFile = (filePath) => {
    fs.readFile(filePath, 'utf-8', (err, data) => {
      if (err) {
        console.error(err)
        return
      }

      try {
        let svg = tk.renderData(data, verovioOptions);
        let dotIndex = filePath.lastIndexOf('.');
        let svgFilePath = filePath.substring(0, dotIndex) + '.svg';
        fs.writeFile(svgFilePath, svg, writingError => {
          if (err) {
            console.error(writingError)
            return
          }
          //file written successfully
        })
        console.log('\x1b[32m%s\x1b[0m', 'Successfully rendered ' + svgFilePath)
       
      } catch(renderError) {
        console.log('Unable to render ' + filePath + ':')
        //console.error(renderError)
      }
      //console.log(data)

    });
  }


  stream.on('data', function (data) {

    if (data.basename.endsWith('.mei') || data.basename.endsWith('.xml')) {
      let path = data.filepath
      
      processFile(path)

    }

  })

}
