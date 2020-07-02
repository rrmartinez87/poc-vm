parameters {
        
	choice( name: 'location',
            	choices: ['westus', 'westus2'],
                description: 'Select region to perform')
           } 
location="${params.location}"

